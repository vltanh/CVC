# Installation

This repository owns the full CVC pipeline and uses DSC and ClusterMerger as
submodules.

## Submodules

Initialize the required submodules:

```bash
git submodule update --init --recursive
```

Only the following repositories are tracked as submodules:

```text
externals/DSC
externals/ClusterMerger
```

## Build DSC

```bash
cd externals/DSC
bash build.sh
cd ../..
```

This provides the DSC method binaries used by the CVC pipeline, including
`externals/DSC/bin/flow-iter`.

## Build ClusterMerger

```bash
cd externals/ClusterMerger
./setup.sh
./easy_build_and_compile.sh
cd ../..
```

The pipeline looks for the ClusterMerger executable at
`externals/ClusterMerger/cluster_merger`. You can override this with:

```bash
export CLUSTER_MERGER_BIN=/path/to/cluster_merger
```

## Python Dependencies

Install the Python packages used by the wrapper scripts:

```bash
pip install click pandas scipy numpy python-igraph leidenalg networkit infomap
```

## Optional External Binaries

The default CVC pipeline also needs RTRex and WCC. Put the binaries in:

```text
bin/RTRex
bin/constrained_clustering
```

or provide explicit paths:

```bash
export RTREX_BIN=/path/to/RTRex
export WCC_BIN=/path/to/constrained_clustering
```

Median Consensus is only needed for `--merge-method medcon`:

```bash
export PAMCON_BIN=/path/to/consensus
```
