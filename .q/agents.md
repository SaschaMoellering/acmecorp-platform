# Amazon Q Developer Instructions

Use `AGENTS.md` as the repository-wide steering layer.

## General rules

- Follow existing repository structure and deployment patterns.
- Keep changes small, explicit, and easy to review.
- Update code, infrastructure, and docs together when the behavior spans them.

## AWS and infrastructure rules

- Apply AWS best practices for security, least privilege, and explicit configuration.
- Preserve Amazon EKS deployment assumptions already present in the repo.
- Keep Helm, Kubernetes, and Terraform assets aligned when they model the same infrastructure behavior.
- Infrastructure changes must update Terraform when the Terraform layer is the source of truth.
- Do not make AWS-facing changes without checking `infra/terraform/`, `infra/k8s/`, and Helm values for corresponding impact.

## Validation

- Run relevant validation commands for infrastructure, application, or docs changes.
- Prefer existing scripts and workflows over ad hoc commands.
- Do not invent benchmark results, deployment outcomes, or CI status.
