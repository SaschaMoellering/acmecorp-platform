# AppCDS Branch

## Purpose

`cds` is the AppCDS and startup-optimization experiment branch.

It exists to evaluate whether class-data sharing changes startup behavior and related operational tradeoffs for this repository's platform stack.

## Branch

- branch name: `cds`
- experiment type: AppCDS and startup optimization

## What Is Preserved

Preserve on this branch:

- AppCDS-specific Dockerfiles
- class-list and archive generation behavior
- AppCDS-oriented startup flags
- scripts and docs that define the AppCDS workflow

Shared fixes must be adapted carefully if they alter startup semantics, archive generation, or image behavior.

## What Results Prove

Results from `cds` can prove how the AppCDS experiment branch behaves under the measured workflow and benchmark setup.

They can support claims about:

- the startup behavior of the `cds` branch
- the tradeoff profile of the AppCDS setup used in this repository
- whether the AppCDS workflow remained reproducible after repository changes

## What Results Do Not Prove

Results from `cds` do not automatically prove:

- that AppCDS is a universal win for every branch or workload
- that the maintained platform branches would show the same results
- that AppCDS behavior is interchangeable with CRaC or native image behavior
