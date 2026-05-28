import click
import os
import subprocess
from pathlib import Path


def exists(file):
    if not os.path.exists(file):
        return False
    with open(file, "r") as f:
        return f.read(1) is not None


@click.command()
@click.option("--weighting-strategy", required=True, type=int, help="Threshold")
@click.option("--threshold", required=True, type=float, help="Threshold")
@click.option(
    "--input-network",
    required=True,
    type=click.Path(exists=True),
    help="Input edgelist",
)
@click.option(
    "--input-clusterings", required=True, help="Input clusterings", multiple=True
)
@click.option("--output-prefix", required=True, type=click.Path(), help="Output path")
@click.option("--num-processors", required=True, type=int, help="Num processors")
@click.option(
    "--overwrite",
    required=False,
    type=bool,
    default=False,
    help="Whether to overwrite the output file.",
)
def main(
    threshold,
    weighting_strategy,
    input_network,
    input_clusterings,
    output_prefix,
    num_processors,
    overwrite,
):
    cvc_root = Path(__file__).resolve().parents[1]
    cluster_merger_bin = os.environ.get(
        "CLUSTER_MERGER_BIN", cvc_root / "bin" / "cluster_merger"
    )

    clustering_list = os.path.join(output_prefix, "clustering_list.txt")
    output_file = os.path.join(output_prefix, "edge.csv")
    output_log = os.path.join(output_prefix, "log.txt")

    if exists(output_file) and not overwrite:
        exit()

    with open(clustering_list, "w") as f:
        for line in input_clusterings:
            f.write(f"{line}\n")

    subprocess.run(
        [
            f"{cluster_merger_bin}",
            "Weighted",
            "--edgelist",
            input_network,
            "--clustering-list",
            clustering_list,
            "--weighting-strategy",
            f"{weighting_strategy}",
            "--threshold",
            f"{threshold}",
            "--num-processors",
            f"{num_processors}",
            "--output-file",
            "currently unused i think just pass in a random string and it should be ok i think",
            "--output-weighted-graph",
            f"{output_file}",
            "--log-file",
            f"{output_log}",
            "--log-level",
            "1",
        ]
    )


if __name__ == "__main__":
    main()
