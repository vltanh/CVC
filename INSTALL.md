# Installation

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
git submodule update --init
```

The external projects are checked out under:

```text
externals/
  DSC/
  ClusterMerger/
  amazon-RTRExtractor/
  constrained-clustering/
```

## DSC-Flow-Iter

Build only the DSC-Flow-Iter binary needed by this pipeline. Pass `flow-iter`
explicitly so the DSC build does not compile the other methods:

```bash
cd externals/DSC
./build.sh flow-iter
cd ../..
```

Install the wrapper-visible binary:

```bash
mkdir -p bin
cp externals/DSC/bin/flow-iter bin/flow-iter
chmod +x bin/flow-iter
```

The pipeline uses `bin/flow-iter` by default. You can override this with:

```bash
export FLOW_ITER_BIN=/path/to/flow-iter
```

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

Install the wrapper-visible binary:

```bash
mkdir -p bin
cp externals/amazon-RTRExtractor/RTRex/clustering/RTRex bin/RTRex
chmod +x bin/RTRex
```

The pipeline uses `bin/RTRex` by default. You can override this with:

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
mkdir -p bin
cp externals/ClusterMerger/cluster_merger bin/cluster_merger
chmod +x bin/cluster_merger
```

The pipeline uses `bin/cluster_merger` by default. You can override this with:

```bash
export CLUSTER_MERGER_BIN=/path/to/cluster_merger
```

## Post-Processing

Build `constrained-clustering` from the repository root:

```bash
cd externals/constrained-clustering
./setup.sh
./easy_build_and_compile.sh
cd ../..
mkdir -p bin
cp externals/constrained-clustering/build/bin/constrained_clustering bin/constrained_clustering
chmod +x bin/constrained_clustering
```

The pipeline uses `bin/constrained_clustering` by default. You can override this
with:

```bash
export WCC_BIN=/path/to/constrained_clustering
```