# Script Index

This directory contains helper scripts for branch maintenance, deployment, validation, local orchestration, and course automation.

Treat these scripts as operational helpers, not as canonical branch-policy documentation. For branch semantics, use [../docs/branch-model.md](../docs/branch-model.md).

## Branch And Compatibility

- `backport.sh`: branch-porting helper
- `check-branch-parity.sh`: compatibility guard for limited path differences across Java branches

## Local And Test Flows

- `wait-for-compose-health.sh`: waits for the local Compose stack to become healthy
- `smoke-local.sh`: smoke checks against the local gateway
- `run-build-in-jdk.sh`: containerized build helper for a chosen JDK
- `run-tests-in-jdk.sh`: containerized test helper for a chosen JDK
- `run-integration-in-network.sh`: integration-test helper

## AWS / Platform Deployment

- `bootstrap-first-cluster.sh`: post-Terraform cluster bootstrap
- `build-and-push-ecr.sh`: build and push service images
- `render-prod-values.sh`: generate deployment-specific Helm values from Terraform outputs
- `validate-deploy.sh`: Terraform + Helm + manifest validation helper
- `verify-first-deploy.sh`: post-deploy verification helper
- `finalize-alb-dns.sh`: DNS finalization helper for ALB-backed ingress
- `deploy-ui.sh`: build and publish the UI to the Terraform-managed S3 + CloudFront path
- `restore-secrets-if-pending-deletion.sh`: recovery helper for previously scheduled secret deletion
- `setup-prod.sh`: convenience deployment setup helper
- `destroy-acmecorp-aws-resources.sh`: teardown helper; use deliberately

## Course Automation

- `episode/run-all.sh`: course-episode support helper

## Safe Usage Notes

- Review a script before running it against AWS or shared environments.
- Prefer the canonical runbooks under `docs/deployment/` for command order and context.
- Do not assume a script implies blind branch parity or blind merge guidance.
