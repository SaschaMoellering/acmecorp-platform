# Documentation Hub

This directory is organized around a practical documentation split:

- **Getting started**: first-run onboarding and quickstart
- **Architecture**: system design and request flow
- **Deployment**: Terraform, Helm, AWS, and UI hosting
- **Operations**: observability, troubleshooting, and verification
- **Development**: local workflows and developer setup
- **Reference**: service inventory, domains, outputs, and environment variables

## Start Here

- [getting-started/quickstart.md](getting-started/quickstart.md)
- [codebase-overview.md](codebase-overview.md)
- [system-map.md](system-map.md)
- [branch-model.md](branch-model.md)
- [benchmarking.md](benchmarking.md)
- [optimizations/README.md](optimizations/README.md)
- [development/local-setup.md](development/local-setup.md)
- [architecture/system-overview.md](architecture/system-overview.md)

## AI Agent Readiness

- Start at [../AGENTS.md](../AGENTS.md).
- Tool-specific wrappers are [../.codex/agents.md](../.codex/agents.md), [../.kiro/agents.md](../.kiro/agents.md), and [../CLAUDE.md](../CLAUDE.md).
- Use this docs tree for canonical facts. Tool-specific agent files should point here instead of duplicating branch, benchmark, deployment, or service-inventory details.
- Treat `docs/steering/` as historical or compatibility-oriented unless a file explicitly says it is the authoritative source.

## Deployment

- [deployment/terraform.md](deployment/terraform.md)
- [deployment/platform-deployment.md](deployment/platform-deployment.md)
- [deployment/ui-cloudfront.md](deployment/ui-cloudfront.md)

## Operations

- [operations/observability.md](operations/observability.md)
- [operations/troubleshooting.md](operations/troubleshooting.md)

## Reference

- [reference/configuration.md](reference/configuration.md)
- [reference/services.md](reference/services.md)

## Infrastructure And Tooling

- [../infra/README.md](../infra/README.md)
- [../helm/acmecorp-platform/README.md](../helm/acmecorp-platform/README.md)
- [../bench/README.md](../bench/README.md)
- [../scripts/README.md](../scripts/README.md)

## Legacy Content

These folders are still useful, but they are not the primary operational runbooks:

- `docs/course/`
- `docs/episodes/`
- `docs/steering/`
- `docs/standards/`
- `docs/archive/`

Historical top-level docs are retained only as compatibility entry points and now link back into this structure.
