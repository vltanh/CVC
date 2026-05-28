import argparse
import sys
import time
import logging
import subprocess
import shutil
from pathlib import Path

import pandas as pd
import scipy.sparse
import scipy.io
import numpy as np


def parse_args():
    parser = argparse.ArgumentParser(description="Automate Graph Consensus Workflow")
    parser.add_argument(
        "--output-dir",
        required=True,
        type=str,
        help="Directory where results and temp files will be stored",
    )
    parser.add_argument(
        "--graph",
        required=True,
        type=str,
        help="Input Graph CSV (Headers: source, target)",
    )
    parser.add_argument(
        "--clusters",
        nargs="+",
        required=True,
        help="List of input clustering CSV files (Headers: node_id, cluster_id)",
    )
    parser.add_argument(
        "--bin",
        default="./pamcon/consensus",
        type=str,
        help="Path to the consensus executable",
    )
    parser.add_argument(
        "--stage-prefix",
        default="input_cluster",
        type=str,
        help="Prefix for staged clustering files inside output dir",
    )
    parser.add_argument(
        "--out-prefix",
        default="com",
        type=str,
        help="Prefix for the final result files",
    )
    return parser.parse_args()


# --- Main Logic Functions ---


def get_global_node_map(csv_path):
    """
    Reads the edge list and returns:
    1. node_map: {original_id -> int} for input processing
    2. inverse_map: {int -> original_id} for output post-processing
    """
    logging.info(f"Deriving global node map from {csv_path}...")
    try:
        df = pd.read_csv(csv_path)
        if "source" not in df.columns or "target" not in df.columns:
            raise ValueError("CSV must have 'source' and 'target' headers.")

        # 1. Unique nodes (sorted for determinism)
        unique_nodes = pd.unique(df[["source", "target"]].values.ravel("K"))
        unique_nodes.sort()

        # 2. Create Maps
        node_map = {node: i for i, node in enumerate(unique_nodes)}
        inverse_map = {i: node for i, node in enumerate(unique_nodes)}

        logging.info(f"Universe size: {len(node_map)} nodes.")
        return node_map, inverse_map
    except Exception as e:
        logging.error(f"Failed to create node map: {e}")
        sys.exit(1)


def convert_graph_to_mtx(csv_path, mtx_out_path, node_map):
    """
    Converts edge list to Matrix Market format using the provided node_map.
    """
    logging.info(f"Writing graph to {mtx_out_path}...")
    try:
        df = pd.read_csv(csv_path)

        # Map to integers
        row_indices = df["source"].map(node_map).values
        col_indices = df["target"].map(node_map).values

        num_nodes = len(node_map)
        # Unweighted graph -> ones (consensus binary typically expects unweighted or specific format)
        data = np.ones(len(df))

        # Create sparse matrix (COO format)
        coo = scipy.sparse.coo_matrix(
            (data, (row_indices, col_indices)), shape=(num_nodes, num_nodes)
        )

        scipy.io.mmwrite(mtx_out_path, coo)
    except Exception as e:
        logging.error(f"Failed graph conversion: {e}")
        sys.exit(1)


def process_clusterings(cluster_files, output_dir, file_prefix, node_map):
    """
    Converts cluster CSVs (node_id, cluster_id) to space-separated format.
    Handles missing nodes as singletons.
    """
    logging.info(f"Processing {len(cluster_files)} clustering files...")

    # Base path for the staged files
    base_prefix_path = output_dir / file_prefix

    # Complete set of all known nodes (integers)
    global_node_set = set(node_map.values())

    for i, file_path in enumerate(cluster_files):
        dest_path = f"{base_prefix_path}.{i}"

        try:
            df = pd.read_csv(file_path)

            if "node_id" not in df.columns or "cluster_id" not in df.columns:
                logging.error(f"File {file_path} missing 'node_id' or 'cluster_id'.")
                sys.exit(1)

            # Map to integers
            df["node_int"] = df["node_id"].map(node_map)

            # Filter valid nodes (drop those not in edge list)
            valid_mask = df["node_int"].notna()
            if not valid_mask.all():
                dropped_count = len(df) - valid_mask.sum()
                logging.warning(
                    f"Dropped {dropped_count} nodes from {file_path} (not in edge list)."
                )

            df = df[valid_mask].copy()
            df["node_int"] = df["node_int"].astype(int)

            # Group by cluster_id -> list of node_ints
            clusters = df.groupby("cluster_id")["node_int"].apply(list)

            # Calculate Missing Nodes (Singletons)
            clustered_nodes = set(df["node_int"].unique())
            missing_nodes = global_node_set - clustered_nodes

            # Write to file
            with open(dest_path, "w") as f:
                # Write existing clusters
                for node_list in clusters:
                    line = " ".join(map(str, node_list))
                    f.write(line + "\n")

                # Write singletons (one per line)
                for node in missing_nodes:
                    f.write(f"{node}\n")

        except Exception as e:
            logging.error(f"Failed processing cluster {file_path}: {e}")
            sys.exit(1)

    return base_prefix_path


def run_pamcon_command(binary_path, mtx_file, input_prefix, output_prefix, k):
    """Constructs and runs the subprocess command.
    k: Number of input clusterings.
    """

    if not Path(binary_path).is_file():
        logging.error(f"Binary not found at: {binary_path}")
        sys.exit(1)

    cmd = [
        str(binary_path),
        "--graph-file",
        str(mtx_file),
        "--input-prefix",
        str(input_prefix),
        "--k",
        str(k),
        "--output-prefix",
        str(output_prefix),
        "--pre-proc-threshold",
        "0.99",
        "--alg",
        "v8-parallel",
    ]

    logging.info(f"Running Command: {' '.join(cmd)}")

    try:
        # We allow subprocess output to flow to stdout
        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError as e:
        logging.error(f"Command failed with exit code {e.returncode}.")
        sys.exit(e.returncode)


def post_process_solution(output_dir, out_prefix_str, inverse_map):
    """
    Reads the .soln-0 file.
    1. Filters singletons (clusters size < 2).
    2. Maps internal ints back to original IDs.
    3. Assigns new CONTINUOUS cluster IDs (0, 1, 2...).
    4. Saves to CSV.
    """
    # Construct paths using Path objects, though subprocess uses strings
    soln_file = Path(f"{out_prefix_str}.soln-0")
    final_csv_path = output_dir / "com.csv"

    logging.info(f"Post-processing solution: {soln_file}")

    if not soln_file.exists():
        logging.error(f"Solution file not found: {soln_file}")
        sys.exit(1)

    final_records = []
    current_cluster_id = 0  # Counter for continuous IDs

    try:
        with open(soln_file, "r") as f:
            for line in f:
                parts = line.strip().split()
                if not parts:
                    continue

                # Filter Singletons
                if len(parts) < 2:
                    continue

                # Map back to Original IDs
                for node_str in parts:
                    node_int = int(node_str)
                    if node_int in inverse_map:
                        original_id = inverse_map[node_int]
                        final_records.append(
                            {"node_id": original_id, "cluster_id": current_cluster_id}
                        )

                # Increment cluster ID only after processing a valid non-singleton cluster
                current_cluster_id += 1

        # Write to CSV
        if final_records:
            df_out = pd.DataFrame(final_records)
            df_out.to_csv(final_csv_path, index=False)
            logging.info(
                f"Removed singletons. Retained {len(df_out)} nodes in {current_cluster_id} clusters."
            )
        else:
            logging.warning("Result contained only singletons. CSV is empty.")

    except Exception as e:
        logging.error(f"Failed during post-processing: {e}")
        sys.exit(1)


# --- Execution Flow ---

if __name__ == "__main__":
    args = parse_args()

    # Path objects
    output_dir = Path(args.output_dir)
    graph_path = args.graph
    cluster_paths = args.clusters
    binary_path = args.bin
    stage_prefix = args.stage_prefix
    out_prefix = args.out_prefix

    # Ensure output directory exists
    output_dir.mkdir(parents=True, exist_ok=True)

    # Configure Logging
    logging.basicConfig(
        filename=output_dir / "run.log",
        filemode="w",
        level=logging.INFO,
        format="%(asctime)s - %(levelname)s - %(message)s",
    )
    # Add stdout handler
    logging.getLogger().addHandler(logging.StreamHandler(sys.stdout))

    # 1. Generate Maps
    start = time.perf_counter()
    node_map, inverse_map = get_global_node_map(graph_path)
    elapsed = time.perf_counter() - start
    logging.info(f"[TIME] Loading network & generating map: {elapsed:.4f}s")

    # 2. Convert Graph to MTX
    start = time.perf_counter()
    mtx_path = output_dir / "graph.mtx"
    convert_graph_to_mtx(graph_path, mtx_path, node_map)
    elapsed = time.perf_counter() - start
    logging.info(f"[TIME] Converting graph to MTX: {elapsed:.4f}s")

    # 3. Transform Clusterings
    start = time.perf_counter()
    consensus_input_prefix = process_clusterings(
        cluster_paths, output_dir, stage_prefix, node_map
    )
    elapsed = time.perf_counter() - start
    logging.info(f"[TIME] Processing input clusterings: {elapsed:.4f}s")

    # 4. Run Consensus Binary
    start = time.perf_counter()
    final_output_prefix = output_dir / out_prefix
    num_clusterings = len(cluster_paths)

    run_pamcon_command(
        binary_path,
        mtx_path,
        consensus_input_prefix,
        final_output_prefix,
        num_clusterings,
    )
    elapsed = time.perf_counter() - start
    logging.info(f"[TIME] Running consensus binary: {elapsed:.4f}s")

    # 5. Post-Process
    start = time.perf_counter()
    post_process_solution(output_dir, str(final_output_prefix), inverse_map)
    elapsed = time.perf_counter() - start
    logging.info(f"[TIME] Saving results: {elapsed:.4f}s")
