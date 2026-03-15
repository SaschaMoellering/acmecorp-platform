# Kiro Agent Instructions

Use the repository-wide steering in `AGENTS.md` as the primary source of truth.

## Allowed tools

- read
- write
- shell

## Allowed paths

- `src`
- `tests`
- `docs`

When work requires files outside those paths, follow repository policy and keep changes minimal.

## Operating rules

- Read `AGENTS.md` before making changes.
- Respect the current branch’s Java compatibility target.
- Reuse existing scripts, tests, and documentation patterns.
- Validate edits with the smallest relevant command or test.
- Update docs when behavior or workflows change.
- Do not invent benchmark values or deployment state.
