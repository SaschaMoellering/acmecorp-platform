# AcmeCorp Platform — AI Agent Guide

This repository supports AI coding agents that edit application code, infrastructure, benchmarks, and course material. Treat this file as the repository-wide steering layer for any agent working here.

## Project Overview

AcmeCorp Platform is a teaching and demonstration repository for:

- modern Java microservice architectures
- Spring Boot and Quarkus service development
- Docker Compose, Kubernetes, Helm, and Amazon EKS deployment flows
- Terraform-managed infrastructure
- Prometheus and Grafana observability
- startup and runtime benchmarking across Java platform branches

The repository is intentionally used for both runnable software and course content. Code, benchmarks, diagrams, and documentation are part of the product.

## Architecture Principles

- Preserve clean service boundaries between gateway, backend services, UI, and infrastructure.
- Prefer explicit, teachable implementations over clever or overly abstract code.
- Keep framework conventions intact unless there is a strong reason to diverge.
- Maintain observability as a first-class concern. Metrics, health endpoints, and dashboards are not optional extras.
- Do not introduce cross-service coupling that makes the architecture harder to explain or operate.

## Repository Structure

Important top-level areas:

- `services/spring-boot/` — Spring Boot services such as orders, billing, analytics, and notifications
- `services/quarkus/` — Quarkus services such as catalog
- `webapp/` — React + Vite frontend
- `infra/local/` — Docker Compose and local runtime support
- `infra/k8s/` — Kubernetes manifests
- `infra/terraform/` — Terraform infrastructure definitions
- `infra/observability/` — Prometheus, Grafana, ServiceMonitors, dashboards
- `charts/` and `helm/` — Helm packaging and deployment assets
- `integration-tests/` — integration test suite
- `bench/` — benchmark harness, collection scripts, and results
- `docs/` — course material, architecture notes, standards, and episode assets
- `.github/workflows/` — CI automation and repository workflows
- `.codex/steering/` — deeper architecture, coding, observability, and benchmarking guidance

## Branch Strategy

This repository uses long-lived platform branches aligned to Java generations and optimization tracks.

Examples:

- `java11`
- `java17`
- `java21`
- `java25`

Agent requirements:

- Preserve compatibility with the Java target of the current branch.
- Do not introduce APIs, plugins, bytecode targets, or container images that violate the branch’s Java level.
- When backporting or forward-porting a change, check framework, plugin, and runtime compatibility before editing.
- Treat cross-branch comparisons as platform branch comparisons unless the repository explicitly isolates the JVM as the only changing variable.

## Coding Rules

- Make minimal, reviewable changes by default.
- Follow existing module structure, naming, and framework conventions.
- Keep configuration explicit and environment-driven where the repository already does so.
- Preserve public endpoints, contract shapes, and service health behavior unless the task explicitly changes them.
- Keep ASCII by default in source and docs unless a file already uses non-ASCII.
- Update nearby docs when behavior, workflow, or developer expectations change.
- Avoid dead code, speculative abstractions, and large refactors unrelated to the task.

## Testing Rules

- Run the smallest relevant test set that validates your change.
- For service code, prefer module-local tests first, then broader integration checks if the change crosses boundaries.
- For infrastructure or deployment changes, validate rendered manifests, chart values, or Terraform formatting/validation where practical.
- For benchmark and documentation work, validate scripts, source files, and generated assets instead of inventing ad hoc measurements.
- If tests are skipped or cannot be run, say so clearly.

## CI and Workflow Rules

- Respect existing GitHub Actions workflows under `.github/workflows/`.
- Do not break CI assumptions around Maven, Docker Compose, Helm, Terraform, Prometheus, or Grafana assets.
- If a change affects build, deployment, or benchmark workflows, update the relevant scripts or docs in the same change.
- Keep generated outputs out of commits unless the repository intentionally tracks them.

## Deployment Model

The platform supports multiple operating modes:

- local development with Docker Compose under `infra/local/`
- Kubernetes deployment using manifests under `infra/k8s/`
- Helm-based deployment via `charts/` and `helm/`
- Amazon EKS deployment patterns supported by Helm and Terraform assets

Agent requirements:

- Keep Docker Compose, Kubernetes, Helm, and Terraform representations aligned when the same behavior is modeled in more than one place.
- Infrastructure changes must preserve observability wiring, service discovery, and configuration overrides.
- Do not silently break EKS assumptions, IAM-related Terraform wiring, or Helm values structure.

## Observability Rules

- Do not remove or silently rename metrics endpoints without updating scrape configs and dashboards.
- Preserve Prometheus compatibility for Spring Boot actuator metrics and Quarkus metrics endpoints.
- Keep Grafana dashboards, datasource assumptions, and ServiceMonitor resources aligned with any observability changes.
- If labels, metric names, or scrape paths change, update the corresponding observability docs and assets.

## Benchmarking Rules

This repository contains benchmark-driven comparisons and course assets based on those results.

Agents must protect:

- reproducibility
- comparability
- benchmark methodology
- historical baseline integrity

Specific rules:

- Reuse existing benchmark scripts and workflows from `bench/` before inventing new commands.
- Do not mix one-off measurements into published benchmark docs if the repository already has a standard repeated-run workflow.
- A code change that alters benchmark results is not automatically wrong, but it must be clearly identified and documented.
- Benchmark diagrams and teleprompter content must reflect measured data, not assumptions.

## Documentation Rules

Documentation here is operational, educational, and benchmark-facing.

- Keep docs aligned with implementation changes.
- Update episode assets, diagrams, and teleprompter scripts when benchmark or workflow behavior changes.
- Keep Mermaid diagrams slide-friendly and technically honest.
- Prefer repository-specific instructions over generic prose.

## Agent Operating Rules

Before making substantial changes:

1. Read this file.
2. Read the relevant guidance under `.codex/steering/`.
3. Inspect the local code and scripts before proposing new architecture or workflow.

While working:

- Prefer existing scripts, Make targets, workflows, and helper commands.
- Preserve branch-specific compatibility and benchmark comparability.
- Do not fabricate benchmark values, test results, or deployment status.
- If you change behavior, update the most relevant docs in the same task when feasible.
- Call out risk when a change touches infrastructure, observability, or benchmarking semantics.

If in doubt:

- choose the smallest safe change
- validate with the closest existing test or script
- document what you changed and what you did not verify
