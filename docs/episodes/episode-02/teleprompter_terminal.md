# Episode 2 — Docker Compose Startup (Terminal Moment – Sprecherfassung)

## Terminal Moment – Watching the system boot

**[SHOW: Terminal – `docker compose up --build` running]**

What you’re seeing here is not just Docker output scrolling by.

This is the AcmeCorp platform **booting as a system**.

Docker Compose is doing several things in a very specific order.

First, it builds all service images from their Dockerfiles.

That already tells us something important: every service is self-contained and reproducible.

There is no hidden setup on my machine.

---

Now Docker creates a dedicated network for the platform.

Every container you see here will live inside that network.

That’s why services can talk to each other by name.

There are no IP addresses hardcoded anywhere.

---

Next, the infrastructure services start.

Postgres.

RabbitMQ.

Redis.

Notice that Docker does **not** immediately start the application services.

Instead, it waits.

---

This waiting is intentional.

Docker Compose continuously evaluates the health checks of these infrastructure containers.

Postgres must accept connections.

RabbitMQ must be fully initialized.

Redis must respond to pings.

Only when those checks pass does Compose move on.

---

Now the backend services start one by one.

Orders.

Billing.

Notification.

Analytics.

Each of them starts only after its dependencies are reported as healthy.

If something blocks here, that is not a Docker issue.

That is a signal that our architecture or configuration needs attention.

---

Finally, the Gateway starts.

This is deliberate.

The Gateway is the entry point.

It should only accept traffic once the entire backend is actually usable.

At this point, the platform is ready.

---

This terminal output already tells us a lot about the system:

* how long startup takes
* where delays happen
* which dependencies are critical

Later in the course, we will revisit this exact moment.

When we talk about readiness.

When we talk about restore behavior.

And when we talk about performance.

For now, the key takeaway is simple:

This is not noise.

This is the system revealing how it really behaves.
