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

I’ve been working as a software developer, software architect, and solutions architect for more than twenty years.

Over that time, I’ve built systems myself, I’ve operated them in production, and I’ve seen them run — and sometimes fail — in real customer environments.

I’ve worked with small teams and large organizations, with simple deployments and highly complex platforms. And across all of that experience, one pattern keeps repeating.

---

> **Why this course exists**

Most systems don’t fail because of missing features.

They fail because of misunderstood trade-offs.

Startup time suddenly matters when you move to containers.
Memory behaves differently than expected.
Observability is added too late.
Infrastructure choices amplify assumptions that were never validated.

This course exists because I’ve seen these problems again and again — not in theory, but in production.

---

> **Why another course?**

There is no shortage of content about Java, Spring, Kubernetes, or cloud architecture.

But most of it falls into one of two extremes.

Either it’s highly simplified demos that work perfectly on a laptop but fall apart in real systems.

Or it’s extremely specialized deep dives that assume you already understand how everything fits together.

This course deliberately sits between those two extremes.

---

> **What makes this course different**

This is not a framework tutorial.

We are not here to learn APIs in isolation.

Instead, we look at how systems actually behave at runtime.

We look at how architecture decisions show up later as startup delays, memory pressure, or operational complexity.

And we do that using a realistic reference system.

---

> **The AcmeCorp Platform**

Throughout the course, we use a system called the AcmeCorp Platform.

It’s intentionally boring in its business domain — orders, catalog, notifications.

That’s a deliberate choice.

A boring domain allows us to focus on what really matters:
architecture, performance, observability, and operations.

This is not a toy demo.
It’s a platform designed to behave like real systems behave.

---

> **Who this course is for**

This course assumes that you already know how to write code.

It’s for engineers who have shipped software.
Who have seen things behave differently in production than they did in development.

If you’re looking for step-by-step tutorials or certification-style content, this course is probably not the right fit.

---

> **How the course is structured**

We start locally.

We look at service boundaries, local development, and reproducibility.

Then we move into observability and performance problems.

Only after that do we talk about JVM optimizations, cloud deployment, and benchmarking.

That order is intentional.

You can’t optimize or operate what you don’t understand.

---

> **What you should expect**

You’ll see code being read and explained.
You’ll see systems being started, broken, and fixed.

You’ll see trade-offs discussed openly — including cases where there is no perfect solution.

The goal is not to give you recipes.
The goal is to give you intuition.

---

> **Closing**

If you care about building systems that behave well under real-world conditions — not just in demos — you’re in the right place.

Let’s start by looking at the platform itself.

