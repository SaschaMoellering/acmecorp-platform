# GraalVM Branch

## Purpose

`graalvm` is the GraalVM and native-image experiment branch.

It exists to evaluate native-image startup, packaging, and runtime tradeoffs for the platform.

## Branch

- branch name: `graalvm`
- experiment type: GraalVM and native image

## What Is Preserved

Preserve on this branch:

- native-image Maven profiles
- GraalVM-oriented Dockerfiles
- reflection and resource configuration
- scripts, CI assumptions, and docs required for native-image validation

New entities, DTOs, repositories, serialization paths, and reflection-heavy changes may require native-image validation before they are safe on this branch.

## What Results Prove

Results from `graalvm` can prove how the native-image experiment branch behaves under the measured workflow.

They can support claims about:

- startup behavior of the `graalvm` branch
- native-image-specific operational tradeoffs in this repository
- whether the branch remains compatible with the repository's current runtime paths

## What Results Do Not Prove

Results from `graalvm` do not automatically prove:

- that native image is better for every service or workload
- that maintained JVM branches would show the same characteristics
- that new runtime-facing code is safe without branch-specific native-image validation
