# Optimization Branches

This directory contains the canonical overview for the repository's optimization and runtime experiment branches.

These branches are separate experiments, not cumulative layers by default:

- `cds` = AppCDS and startup-optimization experiment
- `crac` = CRaC and checkpoint-restore experiment
- `graalvm` = GraalVM and native-image experiment

Interpretation rules:

- results are experiment-specific unless the benchmark scope proves something narrower or broader
- AppCDS and CRaC are not combined by default
- do not describe these branches as a single optimization ladder
- preserve each experiment's runtime semantics when porting shared fixes

Canonical per-branch overviews:

- [cds.md](cds.md)
- [crac.md](crac.md)
- [graalvm.md](graalvm.md)

Related references:

- [../branch-model.md](../branch-model.md)
- [../benchmarking.md](../benchmarking.md)
