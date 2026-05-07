# Benchmarking Steering

This file is a Codex compatibility note.

Canonical benchmark guidance lives in:

- `../../docs/benchmarking.md`
- `../../docs/branch-model.md`
- `../../bench/README.md`

Rules:

- Treat `java11`, `java17`, `java21`, and `java25` comparisons as platform-branch comparisons unless the harness isolates only the JVM.
- Reuse the existing scripts in `bench/` before inventing one-off commands.
- Never edit course or benchmark docs as if single-run numbers were canonical results.
