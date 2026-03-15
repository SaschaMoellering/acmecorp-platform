# Codex Agent Instructions

These instructions apply to OpenAI Codex working in this repository.

## Startup

Before editing:

1. Read `AGENTS.md`.
2. Read the relevant files in `.codex/steering/`.
3. Inspect the local module, script, or document you are changing.

## Working Style

- Prefer minimal diffs.
- Keep changes reviewable and local to the task.
- Reuse existing repository patterns before introducing new ones.
- Preserve the teachable structure of the codebase and docs.

## Validation

- Always run relevant tests or validation commands for the change.
- Start with the smallest meaningful validation scope.
- For docs and benchmark assets, validate source-of-truth files and scripts, not invented measurements.
- If you cannot run validation, state that explicitly.

## Documentation

- Update documentation when implementation, workflow, or benchmark behavior changes.
- Keep episode assets and Mermaid diagrams aligned with the underlying code or measured data.
- Never fabricate benchmark numbers or CI results.

## Benchmarks

- Follow the benchmark methodology already present in `bench/`.
- Protect comparability across `java11`, `java17`, `java21`, and `java25`.
- Treat branch comparisons as maintained platform branch comparisons unless the repo explicitly isolates the JVM as the only variable.
