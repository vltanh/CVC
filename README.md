# CVC Pipeline

This repository contains the full Constrained Voting Consensus (CVC) pipeline
from the journal manuscript. It owns the orchestration scripts for running base
clusterings (DSC-Flow-Iter, Leiden-Mod, RTRex, and IKC(5)), building a consensus
network with ClusterMerger, and applying the final Leiden-CPM(0.01)+WCC step.

## Repository Structure

```text
externals/
  DSC/             # DSC method binaries, including DSC-Flow-Iter
  ClusterMerger/   # consensus-network construction
  amazon-RTRExtractor/ # RTRex method binaries
  constrained-clustering/ # Leiden-CPM(0.01)+WCC method binaries
bin/              # local runtime binaries, ignored by git
examples/
  input/           # real-network edge lists
  output/          # generated outputs, ignored by git
pipelines/
  cvc_pipeline.sh
pipeline.sh       # top-level entry point
scripts/
  methods/         # wrappers for Leiden, IKC, RTRex, Infomap
  run_merger.py
  run_pamcon.py
  unweight.py
```

External source dependencies live under `externals/`. Runtime executables are
copied into `bin/` and used from there by default.

## Installation

See [INSTALL.md](INSTALL.md).

## Running The Pipeline

Default CVC pipeline:

```bash
./pipeline.sh examples/input/dnc.csv examples/output/dnc
```

By default, the pipeline uses DSC-Flow-Iter, Leiden-Mod, RTRex, and IKC(5) as
base clusterings. It constructs a constrained-voting majority-rule consensus
network with ClusterMerger, unweights that network, then runs
Leiden-CPM(0.01)+WCC.

The final default output is:

```text
examples/output/dnc/merge/fmrkc-cvc/final+wcc/com.csv
```

Median Consensus mode:

```bash
./pipeline.sh examples/input/dnc.csv examples/output/dnc-medcon \
  --merge-method medcon \
  --algos leiden-mod leiden-cpm-0.01+wcc
```
