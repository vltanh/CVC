import sys
import time
import logging
import argparse
import subprocess
import os
from pathlib import Path

import pandas as pd


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--edgelist",
        type=str,
        required=True,
    )
    parser.add_argument(
        "--output-directory",
        type=str,
        required=True,
    )
    return parser.parse_args()


args = parse_args()

edgelist_fn = Path(args.edgelist).resolve()
output_dir = Path(args.output_directory).resolve()
cvc_root = Path(__file__).resolve().parents[2]

output_dir.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    filename=output_dir / "run.log",
    filemode="w",
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
)
logging.getLogger().addHandler(logging.StreamHandler(sys.stdout))

start = time.perf_counter()

logging.info(f"Reading edgelist from {edgelist_fn}...")

df_edges = pd.read_csv(edgelist_fn, dtype=str)

unique_nodes = pd.unique(df_edges[["source", "target"]].values.ravel("K"))
num_vertices = len(unique_nodes)
num_edges = len(df_edges)

node_map = {node: i for i, node in enumerate(unique_nodes)}
inv_node_map = {i: node for node, i in node_map.items()}

df_edges["source_int"] = df_edges["source"].map(node_map)
df_edges["target_int"] = df_edges["target"].map(node_map)

temp_edgelist_path = output_dir / "temp.edgelist"

logging.info(f"Writing formatted edgelist to {temp_edgelist_path}")
logging.info(f"Graph stats: Vertices={num_vertices}, Edges={num_edges}")

with open(temp_edgelist_path, "w") as f:
    f.write(f"{num_vertices} {num_edges}\n")

df_edges[["source_int", "target_int"]].to_csv(
    temp_edgelist_path, sep=" ", index=False, header=False, mode="a"
)

elapsed = time.perf_counter() - start
logging.info(f"[TIME] Loading network and formatting: {elapsed:.4f}s")

start = time.perf_counter()

binary_path = Path(
    os.environ.get(
        "RTREX_BIN",
        cvc_root / "bin" / "RTRex",
    )
).resolve()
output_basename = "com"

if not binary_path.exists():
    logging.error(f"Binary not found at {binary_path}. Please check the path.")
    sys.exit(1)

cmd = [str(binary_path), str(temp_edgelist_path), output_basename, "0.1", "s"]

logging.info(f"Switching working directory to: {output_dir}")
logging.info(f"Executing command: {' '.join(cmd)}")

try:
    subprocess.run(
        cmd,
        cwd=output_dir,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
except subprocess.CalledProcessError as e:
    logging.error(f"Binary execution failed: {e.stderr}")
    sys.exit(1)

elapsed = time.perf_counter() - start
logging.info(f"[TIME] Running RTRex algorithm: {elapsed:.4f}s")

start = time.perf_counter()

expected_output_file = output_dir / f"RTRex-{output_basename}-decomposition.txt"

if not expected_output_file.exists():
    logging.error(f"Expected output file {expected_output_file} was not found.")
    sys.exit(1)

logging.info(f"Processing clustering from {expected_output_file.name}...")

results = []
singleton_count = 0
current_cluster_id = 0

with open(expected_output_file, "r") as f:
    for line in f:
        nodes = line.strip().split()

        if len(nodes) > 1:
            for node_int_str in nodes:
                results.append(
                    {"node_int": int(node_int_str), "cluster_id": current_cluster_id}
                )
            current_cluster_id += 1
        else:
            singleton_count += 1

logging.info(f"Ignored {singleton_count} singleton clusters.")
logging.info(f"Found {current_cluster_id} valid communities.")

df_clusters = pd.DataFrame(results)

if df_clusters.empty:
    logging.warning("No non-singleton clusters found!")
    final_output_path = output_dir / "com.csv"
    df_empty = pd.DataFrame(columns=["node_id", "cluster_id"])
    df_empty.to_csv(final_output_path, sep=",", index=False)
    logging.info(f"Final clustering saved to {final_output_path}")
else:
    df_clusters["node_original"] = df_clusters["node_int"].map(inv_node_map)
    final_output_path = output_dir / "com.csv"

    df_clusters[["node_original", "cluster_id"]].to_csv(
        final_output_path, sep=",", index=False, header=["node_id", "cluster_id"]
    )
    logging.info(f"Final clustering saved to {final_output_path}")

temp_edgelist_path.unlink(missing_ok=True)

elapsed = time.perf_counter() - start
logging.info(f"[TIME] Saving results: {elapsed:.4f}s")
