# CRaC Branch

## Purpose

`crac` is the CRaC and checkpoint-restore experiment branch.

It exists to evaluate startup and restore tradeoffs for a CRaC-enabled runtime and lifecycle.

## Branch

- branch name: `crac`
- experiment type: CRaC and checkpoint-restore

## What Is Preserved

Preserve on this branch:

- CRaC-specific Dockerfiles
- checkpoint and restore lifecycle handling
- Azul CRaC runtime usage
- hooks, scripts, and docs required for the CRaC workflow

Shared fixes must not overwrite the CRaC lifecycle or inject AppCDS or GraalVM assumptions by default.

AppCDS and CRaC remain separate unless a dedicated combined experiment branch is created explicitly.

## What Results Prove

Results from `crac` can prove how the CRaC experiment branch behaves under the measured setup, including restore-oriented startup characteristics.

They can support claims about:

- the startup and restore behavior of the `crac` branch
- the operational tradeoffs of this repository's CRaC workflow
- whether the CRaC branch remains internally consistent after shared fixes

## What Results Do Not Prove

Results from `crac` do not automatically prove:

- that CRaC is a universal win for every branch or workload
- that maintained platform branches inherit the same behavior
- that CRaC results can be merged conceptually with AppCDS or native-image results
