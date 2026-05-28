# Installation

This repository uses DSC binaries from `externals/DSC`, Python wrappers, and
external tools stored under `externals/`.

## System Dependencies

Install a C/C++ toolchain and the build tools required by the external projects:

```bash
sudo apt-get install build-essential cmake bison flex
```

On non-Debian systems, install the equivalent packages with the system package
manager.

## External Submodules

After cloning the repository, initialize the external dependencies:

```bash
git submodule update --init --recursive
```

The external projects are checked out under:

```text
externals/
  DSC/
  ClusterMerger/
  amazon-RTRExtractor/
  constrained-clustering/
```

## DSC Methods

Build the DSC binaries from the repository root:

```bash
cd externals/DSC
bash build.sh
cd ../..
```

This writes the DSC executables under `externals/DSC/bin/`.

## Python Dependencies

Install the Python dependencies used by the wrappers and pipeline:

```bash
pip install click pandas scipy numpy python-igraph leidenalg networkit infomap
```

`python-igraph` and `leidenalg` are required for Leiden runs, `networkit` is
required for IKC, `infomap` is required for Infomap, and `pandas`, `numpy`, and
`scipy` are used for CSV and consensus preprocessing.

## RTRex

RTRex is built from `externals/amazon-RTRExtractor`. In an unpatched checkout,
first edit `externals/amazon-RTRExtractor/RTRex/Escape/Nucleus.h` and replace
the two `free(stack)` calls with `delete[] stack`. The stack array is allocated
with `new[]`, and RTRex builds with `-Werror`.

Then build RTRex from the repository root:

```bash
cd externals/amazon-RTRExtractor/RTRex/clustering
make clean
cd ..
make clean
make
cd ../../..
```

The pipeline uses `externals/amazon-RTRExtractor/RTRex/clustering/RTRex`
directly. You can override this with:

```bash
export RTREX_BIN=/path/to/RTRex
```

## Cluster Ensemble

Build `ClusterMerger` from the repository root:

```bash
cd externals/ClusterMerger
./setup.sh
./easy_build_and_compile.sh
cd ../..
```

The pipeline uses `externals/ClusterMerger/cluster_merger` directly, then falls
back to `externals/ClusterMerger/build/bin/cluster_merger`.

## Post-Processing

Build `constrained-clustering` from the repository root:

```bash
cd externals/constrained-clustering
./setup.sh
./easy_build_and_compile.sh
cd ../..
```

The pipeline uses
`externals/constrained-clustering/build/bin/constrained_clustering` directly,
then falls back to `externals/constrained-clustering/constrained_clustering`.

## Median Consensus

Median Consensus is only needed for `--merge-method medcon`. Put the binary at
`bin/consensus`, or provide an explicit path:

```bash
export PAMCON_BIN=/path/to/consensus
```

## Verify The Pipeline

Run the bundled DSC example from the repository root:

```bash
./pipeline.sh externals/DSC/examples/input/dnc.csv output/dnc
```

The default final output is:

```text
output/dnc/merge/fmrkc-cvc/final+wcc/com.csv
```
