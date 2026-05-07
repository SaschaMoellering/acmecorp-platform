# Coding Guidelines

This file is a Codex compatibility note.

Canonical coding and workflow guidance lives in:

- `../../AGENTS.md`
- `../../docs/codebase-overview.md`
- `../../docs/reference/services.md`
- `../../scripts/README.md`

Rules:

- Follow the existing module layout under `services/spring-boot/`, `services/quarkus/`, `webapp/`, `infra/`, `bench/`, and `docs/`.
- Prefer the smallest relevant validation scope instead of broad repository-wide test runs by default.
- Keep service boundaries explicit and independently understandable.
