# CVC Pipeline

This repository contains the full Constrained Voting Consensus (CVC) pipeline.

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