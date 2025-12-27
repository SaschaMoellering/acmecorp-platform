# Documentation

This folder contains the main guides and references for local development, architecture, and infrastructure workflows.

## Getting Started

- [`getting-started.md`](getting-started.md) — Run the stack locally with Docker Compose in under 15 minutes.

## Architecture

- [`architecture/README.md`](architecture/README.md) — Local Docker Compose architecture overview and diagram.
- [`app-architecture-and-branches.md`](app-architecture-and-branches.md) — Application architecture context and branch guidance.

## Infrastructure

- [`kubernetes-deployment.md`](kubernetes-deployment.md) — Kubernetes deployment guide (base manifests).
- [`helm-scaffolding-report.md`](helm-scaffolding-report.md) — Helm scaffolding notes based on the local stack.
- [`aws/aurora-iam-auth.md`](aws/aurora-iam-auth.md) — Aurora IAM authentication setup.

## Observability / Monitoring

- [`infra/observability/`](../infra/observability/) — Grafana dashboards and ServiceMonitors for local/K8s metrics.

## Notifications

- [`notification-system.md`](notification-system.md) — RabbitMQ-backed notification flow and UI integration.

## Testing / Troubleshooting

- [`testing.md`](testing.md) — Practical test commands (unit + integration).
- [`testing-guide.md`](testing-guide.md) — Expanded testing reference.
- [`redis-testing-guide.md`](redis-testing-guide.md) — Redis integration testing walkthrough.
- [`troubleshooting.md`](troubleshooting.md) — Common local issues and fixes.

## Labels

- [`labels.md`](labels.md) — Label definitions for Season 1 vs Season 2 scope.

## Conventions

- Diagrams live in `docs/diagrams/`.
- Mermaid `.mmd` files are the source of truth.
- Rendered `.svg` files are for embedding and export.
