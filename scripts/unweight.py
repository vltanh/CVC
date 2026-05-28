import argparse
from pathlib import Path

import pandas as pd


def main(input_network, output_network):
    Path(output_network).parent.mkdir(exist_ok=True, parents=True)
    df = pd.read_csv(input_network)
    df = df.iloc[:, :2]
    df.columns = ["source", "target"]
    df.to_csv(output_network, index=False)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Process network file.")
    parser.add_argument("--input-network", required=True, help="Input network CSV file")
    parser.add_argument(
        "--output-network", required=True, help="Output network CSV file"
    )
    args = parser.parse_args()
    main(args.input_network, args.output_network)
