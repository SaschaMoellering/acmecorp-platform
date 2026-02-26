# Episode 0 — Course Overview & Goals

This document contains:
- the **episode README** (structure, intent, visuals)
- the **teleprompter script** (spoken narration)

---

## README

### Duration
~7–8 minutes

### Purpose
Set expectations for the course. Explain what the AcmeCorp Platform is, why it exists, and how this course differs from typical cloud or Java tutorials.

This episode allows viewers to decide whether this **paid deep‑dive course** is the right investment for them.

### Target Audience
- Senior Java developers
- Software architects
- Platform, cloud, and infrastructure engineers
- Engineers who already know frameworks and tools, but want to understand **trade‑offs and runtime behavior**

### What This Course Is (and Is Not)

**This course is for people who:**
- have built real systems and felt their limits
- care about startup time, memory, observability, and operability
- want to understand *why* architectural decisions matter at runtime
- are comfortable reading code and infrastructure definitions

**This course is not for people who:**
- want framework tutorials or "Hello World" examples
- are looking for certification prep
- expect one‑size‑fits‑all best practices

### High‑Level Narrative

Most modern systems fail not because of missing features, but because of **misunderstood trade‑offs**.

This course is built around a realistic reference system — the *AcmeCorp Platform* — and uses it to explore how architecture, runtime behavior, performance, observability, and infrastructure interact in practice.

The goal is not to teach tools in isolation, but to develop **system intuition**.

### What Is Shown
- Slides only (no code)
- Course structure and learning path
- Examples of the kinds of questions the course will answer

### What Is Intentionally Deferred
- Any technical deep dive
- Code or infrastructure walkthroughs

---

## TELEPROMPTER SCRIPT

> **Opening – Personal Introduction**

Hi, my name is Sascha.

I've been working as a software developer, software architect, and solutions architect for more than twenty years.

Over that time, I've built systems myself, I've operated them in production, and I've seen them run — and sometimes fail — in real customer environments.

I've worked with small teams and large organizations, with simple deployments and highly complex platforms. And across all of that experience, one pattern keeps repeating.

---

> **Why this course exists**

Most systems don't fail because of missing features. They fail because of misunderstood trade-offs.

For example: Startup time suddenly matters when you move to containers. Memory behaves differently than expected. Observability is added too late. Infrastructure choices amplify assumptions that were never validated.

This course exists because I've seen these problems again and again — not in theory, but in production.

---

> **Why another course?**

Why should you watch this course? Well, that's a good question!

There's no shortage of content about Java, Spring, Kubernetes, or cloud architecture. But most of it falls into one of two extremes.

Either it's highly simplified demos that work perfectly on a laptop but fall apart in real systems. Or it's extremely specialized deep dives that assume you already understand how everything fits together.

This course deliberately sits between those two extremes.

---

> **What makes this course different**

This is not a framework tutorial. If you want to dive into Spring Boot or Quarkus, there are much better courses elsewhere. As a matter of fact, I expect you to have solid knowledge about Spring Boot and Java.

One really important point: We're not here to learn APIs in isolation. Instead, we look at how systems actually behave at runtime.

We look at how architecture decisions show up later as startup delays, memory pressure, or operational complexity. And we do that using a realistic reference system that's easy to understand but implements a meaningful set of features.

---

> **The AcmeCorp Platform**

Throughout the course, we use a system called the AcmeCorp Platform. It's intentionally boring in its business domain — orders, catalog, billing and payments, analytics, notifications, and a gateway service.

This is not due to negligence, but intentional. A boring domain allows us to focus on what really matters: architecture, performance, observability, and operations.


The platform includes six microservices - five built with Spring Boot 3, one with Quarkus 3, all running on Java 21. We have a React and Vite frontend, and a complete observability stack with Prometheus and Grafana. Everything runs locally with Docker Compose, and we'll deploy it to EKS later in the course.

It's important to understand that this is not a toy demo. It's a platform designed to behave like real systems behave. We have database migrations with Flyway, message-driven architecture with RabbitMQ, caching with Redis, and proper health checks and metrics on every service.

-- 

> **Real problems we'll solve**

Let me give you a concrete example of what we'll cover. We have a demo endpoint that intentionally exhibits the N+1 query problem. When you call it, it fetches orders from the database, then makes a separate query for each order's items. One query for the orders, then N queries for the items. Classic N+1.

But we've also built the optimized version that uses a join fetch to grab everything in just two queries. And we have a test that proves it - OrderServiceQueryCountTest that enables Hibernate statistics and asserts that the optimized path runs no more than 3 SQL statements.

This is what I mean by real problems. We're not just talking about N+1 queries in theory. We can reproduce the problem, measure it with metrics, fix it with code, and verify the fix with tests.

---

> **Who this course is for**

Who this course is for
This course assumes that you already know how to write code. It's for engineers who have shipped software. Who have seen things behave differently in production than they did in development.

We have eight episodes planned. We'll cover local development with Docker Compose, JVM deep dives with virtual threads and N+1 queries, deploying and optimizing on EKS Auto Mode, observability with Prometheus and Grafana, reactive patterns in the gateway, catalog and orders management workflows, automation with GitOps and Helm, and monitoring, alerts, and runbook drills.

If you're looking for step-by-step tutorials or certification-style content, this course is probably not the right fit.

---

> **How the course is structured**

We start locally. We look at service boundaries, local development, and reproducibility. We'll use Docker Compose to boot the entire platform on your laptop, and we'll verify that everything works the same way locally as it does in CI.

Then we move into observability and performance problems. We'll set up Prometheus to scrape metrics from all services - Spring Boot services expose /actuator/prometheus, Quarkus exposes /q/metrics. We'll import Grafana dashboards that show JVM memory, thread counts, HTTP request rates, and latency percentiles.

Only after that do we talk about JVM optimizations, cloud deployment, and benchmarking. We'll explore three different optimization strategies - Class Data Sharing with CDS, native images with GraalVM, and Coordinated Restore at Checkpoint with CRaC. Each one has different trade-offs for startup time, memory usage, and build complexity.

That order is intentional. You can't optimize or operate what you don't understand.

---

> **What you should expect**

You'll see code being read and explained. You'll see systems being started, broken, and fixed. We'll run docker compose up and watch the entire platform boot - infrastructure services first, then application services, then the gateway. We'll see health checks pass, we'll seed demo data, we'll make API calls through the gateway.

You'll see metrics in Grafana showing request rates, error rates, and latency. You'll see JVM heap usage and thread counts. You'll see what happens when we call the N+1 endpoint versus the optimized endpoint.

You'll see trade-offs discussed openly — including cases where there is no perfect solution. Should you use Spring Boot or Quarkus? Should you optimize for startup time or memory? Should you use native images or stick with the JVM? The answer is always "it depends," and we'll explore what it depends on.

The goal is not to give you recipes. The goal is to give you intuition.

---

> **Closing**

If you care about building systems that behave well under real-world conditions — not just in demos — you're in the right place.

We have a complete reference system with six microservices, three infrastructure components, a React frontend, and a full observability stack. Everything is in the repository. Everything runs locally. Everything is designed to surface the kinds of problems you'll see in production.

Let's start by looking at the platform itself.

