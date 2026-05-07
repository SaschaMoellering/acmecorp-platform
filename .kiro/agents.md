# Kiro Agent Instructions

Use the repository-wide steering in `AGENTS.md` as the primary source of truth.

Use these canonical docs before relying on any Kiro-local notes:

- `docs/codebase-overview.md`
- `docs/system-map.md`
- `docs/branch-model.md`
- `docs/benchmarking.md`
- `docs/development/local-setup.md`
- `docs/deployment/platform-deployment.md`

## Steering, Specs, And Tasks

- Keep `.kiro/` files short and task-oriented.
- Use Kiro steering files to point back to `AGENTS.md` and the canonical docs, not to restate large architecture or deployment explanations.
- Use Kiro spec or task files only for task-local intent, checklist items, and validation notes.
- Branch model, benchmark methodology, deployment boundaries, and service inventory remain owned by the canonical docs.

## Working Scope

This repository’s normal work spans `services/`, `webapp/`, `infra/`, `helm/`, `bench/`, `scripts/`, and `docs/`. Touch only the files required for the task, but do not assume work is limited to `src/`, `tests/`, or `docs/`.

## Operating rules

- Read `AGENTS.md` before making changes.
- Respect the current branch’s Java compatibility target.
- Reuse existing scripts, tests, and documentation patterns.
- Validate edits with the smallest relevant command or test.
- Update docs when behavior or workflows change.
- Do not invent benchmark values or deployment state.
