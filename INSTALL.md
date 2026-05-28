# Installation

This repository owns the full CVC pipeline and uses DSC and ClusterMerger as
submodules.

## Submodules

Initialize the required submodules:

```bash
git submodule update --init --recursive
```

The following repositories are tracked as submodules:

```text
externals/DSC
externals/ClusterMerger
externals/amazon-RTRExtractor
externals/constrained-clustering
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
`externals/ClusterMerger/cluster_merger`, then falls back to
`externals/ClusterMerger/build/bin/cluster_merger`. You can override this with:

```bash
export CLUSTER_MERGER_BIN=/path/to/cluster_merger
```

## Build RTRex

```bash
git -C externals/amazon-RTRExtractor apply \
  ../../patches/amazon-RTRExtractor-nucleus-stack-delete.patch
cd externals/amazon-RTRExtractor/RTRex
make
cd ../../..
```

The patch replaces two `free(stack)` calls with `delete[] stack` in
`RTRex/Escape/Nucleus.h`. RTRex allocates those arrays with `new[]`, and the
upstream build uses `-Werror`.

The pipeline looks for the RTRex executable at
`externals/amazon-RTRExtractor/RTRex/clustering/RTRex`. You can override this
with:

```bash
export RTREX_BIN=/path/to/RTRex
```

## Build WCC

```bash
cd externals/constrained-clustering
./setup.sh
./easy_build_and_compile.sh
cd ../..
```

The pipeline looks for the WCC executable at
`externals/constrained-clustering/build/bin/constrained_clustering`. You can
override this with:

```bash
export WCC_BIN=/path/to/constrained_clustering
```

## Python Dependencies

Install the Python packages used by the wrapper scripts:

```bash
pip install click pandas scipy numpy python-igraph leidenalg networkit infomap
```

## Optional Median Consensus Binary

Median Consensus is only needed for `--merge-method medcon`. Put the binary in:

```text
bin/consensus
```

or provide an explicit path:

```bash
export PAMCON_BIN=/path/to/consensus
```
