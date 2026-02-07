# Episode 1 — AcmeCorp Platform Overview & Architecture

## Duration
~8–10 minutes

## Purpose
Introduce the AcmeCorp Platform as a realistic reference system and establish a shared mental model of its architecture, domain, and design goals.

After this episode, viewers should understand:
- what the platform is
- what it intentionally is not
- why it is structured the way it is

## Target Audience
- Senior Java developers
- Software architects
- Platform and cloud engineers

## High-Level Narrative

Architectural discussions often fail because they stay abstract.

This episode anchors all future discussions in a **concrete system**: the AcmeCorp Platform.  
The business domain is intentionally simple so that architectural, runtime, and operational aspects remain in focus.

The goal is not to present a perfect architecture, but a *useful* one — realistic enough to expose trade-offs and failure modes.

## The AcmeCorp Platform at a Glance

AcmeCorp is a fictional commerce platform consisting of:
- a **Gateway** as the single external entry point
- multiple backend services such as **Orders**, **Catalog**, and **Notifications**
- supporting infrastructure services (database, messaging, cache)

The platform deliberately resembles systems commonly found in real organizations.

## Architectural Style

The platform follows a **microservices architecture**, but with strong constraints:
- one externally exposed service
- explicit service boundaries
- controlled communication paths
- infrastructure treated as part of the system

Microservices are not used as a default choice, but as a tool to explore:
- startup behavior
- dependency management
- observability
- deployment trade-offs

## Technology Stack (High Level)

- **Spring Boot and Quarkus** for backend services
- **React** for the frontend (kept intentionally separate)
- **Docker and Docker Compose** for local reproducibility
- **Kubernetes and AWS** later in the course, once behavior is understood

## Architecture & Visuals

This episode uses the following diagrams:

- **E01-D01-system-overview** — High-level system architecture
- **E01-D02-service-boundaries** — External vs internal APIs
- **E01-D03-request-flow** — Request flow through the system
- **E01-D04-repo-mapping** — Repository layout mirrors architecture

## What Is Shown
- Architecture diagrams
- High-level request flow
- Repository and module layout

## What Is Intentionally Deferred
- Local development details
- API design specifics
- Kubernetes and cloud deployment
- Performance optimizations

## Outcome of This Episode

After this episode, viewers should have:
- a clear mental model of the system
- an understanding of the architectural constraints
- enough context to follow all later technical deep dives

