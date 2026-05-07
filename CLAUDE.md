# Claude Code Instructions

Start with `AGENTS.md`. Treat it as the canonical repository-wide guide.

Before editing:

1. Read `AGENTS.md`.
2. Read the most relevant canonical docs under `docs/`, `infra/`, `scripts/`, or `bench/`.
3. Inspect the exact files you plan to change.

Working rules:

- Keep diffs minimal and reviewable.
- Preserve branch-specific Java compatibility and benchmark comparability.
- Do not make speculative infrastructure, observability, or benchmark changes.
- Prefer existing scripts and documented workflows over ad hoc commands.
- Update the closest canonical docs when behavior or workflow changes.

Validation:

- Run the smallest meaningful validation for the files you changed.
- Prefer `bash scripts/validate-repo.sh` plus targeted checks such as `helm template`, `terraform fmt -check`, module-local tests, or local smoke checks.
- If you could not run a validation step, say so explicitly.
