# AcmeCorp Agent Instructions

This repository is a production-grade teaching and benchmarking platform for modern Java, cloud-native architecture, and performance engineering.

Agents must read these files before making changes:

- docs/steering/00-project-context.md
- docs/steering/01-architecture-principles.md
- docs/steering/02-repository-structure.md
- docs/steering/03-java-standards.md
- docs/steering/04-benchmark-methodology.md
- docs/steering/05-diagram-style.md
- docs/steering/06-ai-agent-guidelines.md
- docs/steering/07-coding-standards.md
- docs/steering/08-course-content-guidelines.md

## Mission

AcmeCorp is used for:

- technical course content
- architecture demonstrations
- startup and runtime performance experiments
- reproducible comparisons across Java and framework versions

The repository is not a toy project.
Changes must preserve technical credibility, reproducibility, and presentation quality.

## Global Rules

- Do not fabricate benchmark numbers.
- Do not invent timings for JVM internals or framework phases unless the repository already contains instrumentation proving them.
- Do not present estimates as measurements.
- Prefer measured end-to-end application metrics over speculative subsystem breakdowns.
- Keep all generated content consistent with the actual code and benchmark artifacts in the repository.

## Benchmarking Rules

When working on benchmarks, always follow `docs/steering/04-benchmark-methodology.md`.

Default benchmark assumptions unless the repo explicitly defines otherwise:

- metric: time to successful readiness/health HTTP response
- mode: cold start
- statistic shown externally: median
- minimum runs: 5
- identical artifact and identical environment across compared runs

When updating benchmark outputs:

- locate the actual benchmark script, command, or workflow first
- identify where raw results are stored
- derive summary numbers from raw results
- update diagrams and scripts only after validating the measured values

If benchmark data is missing or stale:

- say so explicitly
- propose rerunning the benchmark
- do not guess

## Diagrams

All diagrams must use Mermaid unless another format is already established in the target area.

Diagram rules:

- follow `docs/steering/05-diagram-style.md`
- optimize for GitHub and VS Code rendering stability
- avoid long subgraph titles when they are likely to clip or render badly
- prefer explicit header nodes inside columns over fragile subgraph headings
- keep diagrams presentation-ready and technically honest

For benchmark diagrams:

- prefer total measured startup time over speculative phase breakdowns
- only show sub-phase timings if those phases were actually instrumented and measured
- label methodology clearly where useful, for example:
  - median of 5 cold starts
  - time to health endpoint
  - Java 11 vs 17 vs 21

## Teleprompter and Course Script Rules

When updating teleprompter scripts or slide text:

- keep spoken claims aligned with measured data
- state methodology clearly in speaker-friendly language
- avoid overstating certainty
- prefer phrasing like:
  - "we reran the benchmark under identical conditions"
  - "the metric here is median cold-start time to readiness"
  - "this is an application-level measurement, not a synthetic subsystem estimate"

Do not write narration that implies precision the benchmark does not support.

## Code Change Rules

Before changing code:

- understand the service boundary
- identify framework and Java version constraints
- preserve service independence
- avoid unnecessary abstractions
- prefer clear, maintainable code over clever code

For Java services:

- respect the supported Java versions in `docs/steering/03-java-standards.md`
- do not introduce version-specific features without documenting them
- keep Spring Boot and Quarkus comparisons fair and structurally comparable where possible

## Repository Hygiene

When making changes:

- modify the smallest sensible set of files
- keep naming and directory layout consistent
- do not create duplicate documentation when an existing steering or architecture doc should be updated instead
- keep Markdown clean and renderable on GitHub

## Expected Workflow for Benchmark-Driven Updates

For any task involving benchmark charts, diagrams, README claims, or teleprompter text, use this sequence:

1. Identify benchmark scope and methodology.
2. Locate the real benchmark scripts and raw outputs.
3. Verify whether the data is current.
4. Re-run benchmarks if needed.
5. Summarize measured values.
6. Update diagrams.
7. Update teleprompter/script text.
8. Cross-check all user-facing claims against measured results.

## If Unsure

If the repository does not contain enough evidence for a claim:

- stop
- state what is missing
- ask for or propose the benchmark rerun / measurement step

Accuracy is more important than speed.
