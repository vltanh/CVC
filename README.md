# CVC Pipeline

This repository contains the full Constrained Voting Consensus (CVC) pipeline. It takes as input:
* a network
* a set of base clustering methods
* a final clustering method
* algorithmic parameters (weighting strategy and threshold, whether to consider the final graph weighted or not)
and executes the following steps:
1. Run the base clustering methods on the input network to get a set of base clusterings
2. Run [ClusterMerger](https://github.com/MinhyukPark/ClusterMerger) to get a consensus network based on the base clusterings and the algorithmic parameters
3. Run the final clustering method on the consensus network to get the final clustering

The conference version related to the work (describing an old pipeline) and supplementary materials 
can be found [here](https://doi.org/10.1007/978-3-032-16719-4_3). If you use our work, 
you can use the following BibTeX entry to cite.
```
@InProceedings{10.1007/978-3-032-16719-4_3,
    author="Vu-Le, The-Anh and Lamy, Jo{\~a}o Alfredo Cardoso and Alessi, Tom{\'a}s and Chen, Ian and Park, Minhyuk and Harb, Elfarouk and Chacko, George and Warnow, Tandy",
    editor="Cherifi, Hocine and Rocha, Luis M. and Cherifi, Chantal and Ertem, Zeynep",
    title="Dense Subgraph Clustering and a New Cluster Ensemble Method",
    booktitle="Complex Networks {\&} Their Applications XIV",
    year="2026",
    publisher="Springer Nature Switzerland",
    address="Cham",
    pages="29--40",
    isbn="978-3-032-16719-4"
}
```
The extended version of the work with the new recommended pipeline is under review for journal submission.

## Installation

See [INSTALL.md](INSTALL.md).

## Usage

### Running the recommended pipeline

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

### Customizing the pipeline

The pipeline can be customized by providing additional arguments:

```
> ./pipeline.sh --help

Usage: ./pipeline.sh EDGELIST OUT_ROOT [OPTIONS]

Options:
  --merge-method METHOD       ClusterMerger or pamcon (default: ClusterMerger)
  --algos METHOD ...          base clusterings to use for the consensus
  --final-algo METHOD         final CVC clustering, optionally +wcc (default: leiden-cpm-0.01+wcc)
  --weighting-strategy N      ClusterMerger weighting strategy (default: 0)
  --threshold X               ClusterMerger threshold (default: 0.5)
  --weighted                  keep the ClusterMerger merged graph weighted (default: not set)
  --run-wcc                   run WCC after a pamcon consensus (default: not set)
  --merge-id ID               override the generated merge directory name
  --timeout DURATION          timeout for each stage (default: 5d)

Examples:
  ./pipeline.sh examples/input/dnc.csv examples/output/dnc
  ./pipeline.sh examples/input/dnc.csv examples/output/dnc --merge-method ClusterMerger --algos flow-iter leiden-mod RTRex ikc-5
```

**Specifying clustering methods**: For both the base clustering methods and the final clustering method, 
the following options are available:
- `flow-iter`: DSC-Flow-Iter
- `leiden-cpm-<r>`: Leiden optimizing under CPM with resolution `<r>`
- `leiden-mod`: Leiden-Mod
- `RTRex`: RTRex
- `ikc-<k>`: IKC with minimum k-core value `<k>`
- `infomap`: Infomap

Additionally, if `+wcc` is appended to the method name, WCC will be run after that method. 
For example, `leiden-cpm-0.01+wcc` means Leiden-CPM with resolution parameter 0.01 followed by WCC.

*Note* `--final-algo leiden-cpm-0.01+wcc` and `--final-algo leiden-cpm-0.01 --run-wcc` are equivalent. 

**Weighting strategy and threshold**: These parameters are passed directly to ClusterMerger.

Each clustering is a voter for each edge. There are two voting schemes:

- Free voting (`--weighting-strategy 1`): every clustering is eligible to vote.
  The edge weight is the non-negative integer count of clusterings that
  co-cluster the endpoints.
- Constrained voting (`--weighting-strategy 0`): only clusterings that cluster
  both endpoints are eligible to vote. The edge weight is the count divided by
  the number of eligible voters (`0.0` if there are no eligible voters), so it
  is between `0.0` and `1.0`.

Examples: For majority constrained voting, use threshold `0.5`. For majority free voting, 
use threshold `⌈n/2⌉` where `n` is the number of input clusterings.

**Merge identifier**: If `--merge-id` is not provided, the pipeline builds one
from the base clustering aliases, final clustering alias, and merge
configuration. This automatic resolution is naive and only supports a limited set
of combinations, specifically those in the paper experiments.

The aliases for the clustering methods are `flow-iter` -> `f`, `leiden-mod` -> `m`,
`RTRex` -> `r`, `ikc-5` -> `k`, `leiden-cpm-0.01+wcc` -> `c`, and
`leiden-cpm-0.01` -> `c'`.

For ClusterMerger, the suffix is `cvc` when `--weighting-strategy 0` and
`--threshold 0.5`, and `fvc` when `--weighting-strategy 1` and
`--threshold ceil(n/2)`, where `n` is the number of base clusterings.
