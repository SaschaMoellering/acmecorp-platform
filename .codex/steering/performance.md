# Performance Optimization

This file is a Codex compatibility note.

Canonical performance and optimization guidance lives in:

- `../../docs/benchmarking.md`
- `../../docs/branch-model.md`
- `../../docs/optimizations/README.md`

Rules:

- Preserve benchmark comparability before chasing a local optimization.
- Treat `cds`, `crac`, and `graalvm` as separate experiment branches.
- Do not assume an optimization applies across branches without branch-specific validation.
