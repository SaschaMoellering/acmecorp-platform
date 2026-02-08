# Episode 2 — Local Development & Docker Compose

## Opening – Why local development matters

**[SHOW: Title Slide – “Local Development & Docker Compose”]**

In Episode 1, we built a shared mental model of the AcmeCorp Platform.

We talked about services, responsibilities, and boundaries.

Now it’s time to make that model executable.

Before we touch any cloud environment or CI pipeline, we need to understand how the entire platform runs locally.

Local development is where architecture meets reality.

---

## Local and CI are equal constraints

**[SHOW: E02-D01-compose-architecture.md]**

Local development is not a convenience layer.

If the system behaves differently locally than it does in CI, engineers end up debugging environment differences instead of real bugs.

That’s why, in this course, local development and CI are treated as **equal architectural constraints**.

The same assumptions must hold in both places.

---

## Docker Compose as infrastructure as code

**[SHOW: `infra/local/docker-compose.yml`]**

Docker Compose is not just a tool to start containers.

It is **infrastructure as code**.

This single YAML file defines the entire local platform:

* all microservices
* all infrastructure components
* networking
* startup ordering

If it’s not defined here, it’s not part of the system.

---

## Infrastructure services

**[SHOW: docker-compose.yml – infrastructure section]**

We start with the infrastructure layer.

The AcmeCorp platform uses three core infrastructure services:

* Postgres
* RabbitMQ
* Redis

These are shared by all backend services.

---

## Postgres – relational database

**[SHOW: docker-compose.yml – Postgres service]**

Postgres is our relational database, running on port 5432.

We create a database called `acmecorp`, with matching username and password.

A named volume called `pgdata` is used to persist data between restarts.

This means:

* stopping containers does not delete data
* local restarts behave more like production

The health check runs `pg_isready` every 10 seconds.

This ensures the database is actually accepting connections before dependent services start.

---

## RabbitMQ – message broker

**[SHOW: docker-compose.yml – RabbitMQ service]**

RabbitMQ is our message broker, listening on port 5672.

The management UI is exposed on port 15672.

We configure a default user and password: `acmecorp`.

The health check uses `rabbitmq-diagnostics` to ensure the broker is fully ready.

This is critical.

Starting an application before the broker is ready leads to subtle and hard-to-debug failures.

---

## Redis – caching layer

**[SHOW: docker-compose.yml – Redis service]**

Redis provides caching and fast-access data structures.

It runs on port 6379.

The setup is intentionally simple.

The health check pings Redis every 10 seconds to ensure it is responsive.

---

## Microservices overview

**[SHOW: docker-compose.yml – services section]**

On top of the infrastructure, we run five backend services:

* Orders
* Billing
* Notification
* Analytics
* Catalog

Each service is independently built and started.

But they all share the same infrastructure.

---

## Common service pattern

**[SHOW: docker-compose.yml – one service highlighted]**

Each microservice follows the same structural pattern in Docker Compose:

* build from a Dockerfile in its service directory
* define a local image name and container name
* configure environment variables
* declare dependencies using health checks

This consistency is intentional.

It reduces cognitive load and makes failures easier to reason about.

---

## Orders service example

**[SHOW: docker-compose.yml – orders-service]**

The Orders service runs on port 8081.

It connects to:

* Postgres for order data
* RabbitMQ for publishing domain events
* Redis for caching

It also needs to communicate with other services.

Those service URLs are injected via environment variables, such as `ACMECORP_SERVICES_CATALOG`.

This makes service dependencies explicit and configurable.

---

## Other Spring Boot services

**[SHOW: docker-compose.yml – billing, notification, analytics]**

Billing, Notification, and Analytics follow the same pattern.

They run on ports 8082, 8083, and 8084.

All of them:

* connect to the same Postgres instance
* use the same RabbitMQ broker
* share the same Redis cache

This reflects a realistic local setup.

---

## Catalog service – Quarkus

**[SHOW: docker-compose.yml – catalog-service]**

The Catalog service is implemented using Quarkus instead of Spring Boot.

Because of that, its environment variables use the `QUARKUS_` prefix instead of `SPRING_`.

Aside from that difference, it connects to the same infrastructure and behaves like the other services.

It runs on port 8085.

This allows us to compare frameworks within the same platform.

---

## Gateway service

**[SHOW: docker-compose.yml – gateway-service]**

Finally, we have the Gateway service, running on port 8080.

This is the single external entry point into the platform.

The gateway does not need Postgres, RabbitMQ, or Redis.

It only needs to know how to reach the backend services.

We pass those URLs via environment variables, such as:

* `ORDERS_BASE_URL=http://orders-service:8080`

This keeps the gateway lightweight and focused.

---

## Startup ordering with depends_on

**[SHOW: docker-compose.yml – depends_on]**

Notice the `depends_on` configuration.

Backend services depend on infrastructure with `condition: service_healthy`.

This means Docker Compose waits until Postgres, RabbitMQ, and Redis pass their health checks before starting the services.

The gateway depends on all backend services.

This ensures that routing only starts once the platform is actually usable.

---

## Restart policy and resilience

**[SHOW: docker-compose.yml – restart policy]**

All services use `restart: unless-stopped`.

If a container crashes, Docker automatically restarts it.

Even locally, this gives us a more resilient environment and surfaces crash loops early.

---

## Networking and service discovery

**[SHOW: E02-D02-local-request-flow.md]**

Docker Compose creates a default network for all services.

They can reach each other by service name.

When `orders-service` calls `http://billing-service:8080`, Docker’s internal DNS resolves the service name to the correct container IP.

No hard-coded IP addresses.

No manual networking.

---

## Running the entire platform

**[SHOW: Terminal – starting the stack]**

Now let’s actually start the entire Docker Compose stack.

We do this with a single command:

* `docker compose up --build`

This command does much more than just start containers.

Docker Compose performs several steps in a well-defined order:

1. It builds all service images from their respective Dockerfiles
2. It creates a dedicated Docker network for the platform
3. It starts the infrastructure services first
4. It continuously evaluates their health checks
5. It only starts application services once dependencies are healthy
6. It finally starts the Gateway after all backend services are ready

What we see scrolling by in the terminal is the system *booting*.

This is the first place where startup behavior, delays, or misconfigurations become visible.

If something hangs here, it is almost always a real architectural or dependency problem.

---

## Common Docker Compose commands

**[SHOW: Terminal]**

Some useful commands during development:

* `docker compose down` – stop everything
* `docker compose logs -f` – follow logs
* `docker compose up --build orders-service` – rebuild a single service

These commands make iteration fast and predictable.

---

## Why this matters

This is infrastructure as code.

The entire platform is defined in a single YAML file.

Any developer can:

* clone the repository
* run `docker compose up`
* get a fully working environment

No manual setup.

No configuration drift.

Just reproducible infrastructure.

---

## Closing – Trusting the local environment

By the end of this episode, you should trust your local environment.

That trust is essential.

It allows us to reason about API boundaries, observability, performance, and deployment.

In the next episode, we will zoom in on API boundaries and the Gateway itself.
