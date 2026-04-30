# Infrastructure Docs

This directory contains the runnable infrastructure assets for local development, plain Kubernetes demos, observability, and Terraform-managed AWS provisioning.

Use these docs as the infrastructure-specific source of truth:

- [local/README.md](local/README.md) for local Docker Compose
- [terraform/README.md](terraform/README.md) for Terraform usage and safety
- [k8s/README.md](k8s/README.md) for the plain Kubernetes base manifests
- [observability/README.md](observability/README.md) for Prometheus, Grafana, and ServiceMonitor assets
- [../helm/acmecorp-platform/README.md](../helm/acmecorp-platform/README.md) for the canonical Helm chart

Related canonical docs under `docs/`:

- [../docs/development/local-setup.md](../docs/development/local-setup.md)
- [../docs/deployment/terraform.md](../docs/deployment/terraform.md)
- [../docs/deployment/platform-deployment.md](../docs/deployment/platform-deployment.md)
- [../docs/operations/observability.md](../docs/operations/observability.md)

Notes:

- `infra/local/` is the supported local runtime path.
- `infra/k8s/base/` is a plain-YAML compatibility/demo path, not the canonical AWS deployment path.
- `infra/terraform/` provisions the AWS foundation but does not deploy application images by itself.
