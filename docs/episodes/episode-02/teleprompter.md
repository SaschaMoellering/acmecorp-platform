# Episode 2 — Teleprompter Script

> **Opening – Why local development matters**

[SHOW: title slide – “Local Development & Docker Compose”]

In the previous episode, we built a mental model of the system.

Now it’s time to actually run it.

But before we do that, we need to talk about *why* local development matters as much as CI.

---

> **Local and CI are equal constraints**

[SHOW: E02-D01-compose-architecture]

Local development is not just for convenience.

If your system behaves differently locally than it does in CI, you will spend most of your time debugging differences instead of bugs.

That’s why, in this course, local development and CI are treated as equal architectural constraints.

---

> **Docker Compose as an architectural mirror**

[SHOW: docker-compose.yml]

Docker Compose is not just a way to start containers.

It describes:
- which services exist
- how they depend on each other
- and in which order they become usable

In other words, it mirrors the architecture.

---

> **Service dependencies**

[SHOW: E02-D01-compose-architecture, highlight DB, MQ, cache]

The platform depends on a database, a message broker, and a cache.

These are not mocked away.

They are part of the system.

If a service cannot start without its dependencies, that should be visible locally.

---

> **Startup order and readiness**

[SHOW: E02-D03-startup-health-signals]

Starting a container is not the same as being ready.

Health and readiness signals tell us when a service is actually usable.

We’ll rely on these signals heavily in later episodes.

---

> **Verifying the system locally**

[SHOW: E02-D02-local-request-flow]

Once everything is running, we don’t talk to services directly.

We verify the system through the Gateway.

That way, local behavior already matches how the system will be used later.

---

> **Common local failure modes**

[SHOW: terminal output with failing startup / health]

Missing dependencies.

Wrong startup order.

Services that are “up” but not ready.

These are not inconveniences — they are signals.

---

> **Closing**

By the end of this episode, you should trust your local environment.

That trust is what allows us to reason about observability, performance, and deployment later.

In the next episode, we’ll look at API boundaries and the Gateway in more detail.

