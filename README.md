# CVC Pipeline

This repository contains the full Constrained Voting Consensus (CVC) pipeline
from the journal manuscript.

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