# AcmeCorp Platform — AI Agent Guide

This repository supports AI development agents such as:

- OpenAI Codex
- Amazon Q Developer
- Kiro
- Claude Code

Agents should follow the steering documents in:

.codex/steering/

and the specialized agent definitions in:

.codex/agents/

## Repository Intent

AcmeCorp Platform is a teaching and demonstration repository for:

- modern Java service architectures
- cloud-native deployment models
- observability with Prometheus and Grafana
- startup and runtime optimization across Java generations

## Branch Strategy

Branches represent different Java platform generations and optimization tracks.

Examples:

- java11
- java17
- java21
- java25

Agents MUST preserve compatibility with the Java target of the current branch.

## Architectural Guardrails

- keep service boundaries clean
- avoid unnecessary cross-service coupling
- prefer clear and teachable implementations over clever complexity

## Observability Guardrails

- metrics exposure must remain intact
- Prometheus scraping compatibility must be preserved
- Grafana dashboards and alerting should not break silently

## Benchmarking Guardrails

This repository contains benchmark-driven comparisons.

Agents must protect:

- reproducibility
- comparability
- benchmark methodology
- historical baseline integrity

A code change that alters benchmark results is not automatically wrong,
but it must be clearly identified and documented.

## Documentation Guardrails

Because this repository supports course material and demonstrations,
agents should keep technical documentation aligned with implementation changes.
