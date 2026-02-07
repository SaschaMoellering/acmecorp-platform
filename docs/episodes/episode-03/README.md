# Episode 3 — API Design, Gateway & Service Boundaries

## Duration
~10 minutes

## Purpose
Explain how APIs are exposed, why the Gateway exists, and how service boundaries protect systems from cascading failures.

## High-Level Narrative

> Most distributed systems fail at their boundaries, not in their business logic.

This episode explains why **a single Gateway** is both a technical and organizational decision.

## Key Concepts Covered
- External vs internal APIs
- Gateway pattern in practice
- Routing and aggregation
- Error propagation and retries

## Architecture & Visuals

- **E03-D01-gateway-external-vs-internal**
- **E03-D02-gateway-request-flow**
- **E03-D03-error-propagation-paths**

## What Is Shown
- Gateway routing configuration
- Request flow through the Gateway
- Error handling behavior

## What Is Intentionally Deferred
- Authentication and authorization
- Rate limiting
- Cloud ingress

## Outcome of This Episode

Viewers should understand:
- why only the Gateway is exposed
- how boundaries reduce blast radius
- how API design affects operability

