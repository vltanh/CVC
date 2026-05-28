# CVC Pipeline

This repository contains the full Constrained Voting Consensus (CVC) pipeline
from the journal manuscript. It owns the orchestration scripts for running base
clusterings, building a consensus network with ClusterMerger, optionally running
Median Consensus, and applying the final Leiden-CPM(0.01)+WCC step.

## Repository Structure

```text
externals/
  DSC/             # DSC method binaries, including DSC-Flow-Iter
  ClusterMerger/   # consensus-network construction
pipelines/
  cvc_pipeline.sh
pipeline.sh       # top-level entry point
scripts/
  methods/         # wrappers for Leiden, IKC, RTRex, Infomap, SBM
  run_merger.py
  run_pamcon.py
  unweight.py
```

Only `DSC` and `ClusterMerger` are submodules. Other external binaries, such as
RTRex, WCC, and Median Consensus, are supplied through `bin/` or environment
variables.

## Installation

See [INSTALL.md](INSTALL.md) for submodule, build, Python dependency, and
optional external binary setup.

## Running The Pipeline

Default CVC pipeline:

```bash
./pipeline.sh externals/DSC/examples/input/dnc.csv output/dnc
```

By default, the pipeline uses DSC-Flow-Iter, Leiden-Mod, RTRex, and IKC(5) as
base clusterings. It constructs a constrained-voting majority-rule consensus
network with ClusterMerger, unweights that network, then runs
Leiden-CPM(0.01)+WCC.

The final default output is:

```text
output/dnc/merge/fmrkc-cvc/final+wcc/com.csv
```

Median Consensus mode:

```bash
./pipeline.sh externals/DSC/examples/input/dnc.csv output/dnc-medcon \
  --merge-method medcon \
  --algos leiden-mod leiden-cpm-0.01+wcc
```
