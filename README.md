# AcmeCorp Platform

AcmeCorp Platform is a cloud-native enterprise demo that stitches together Spring Boot, Quarkus, and a Vite/React UI to showcase architecting, deploying, and observing a microservices suite (orders, catalog, billing, analytics, notifications) in Docker, Kubernetes, and EKS labs.

## What’s Included

- **Gateway** – Spring WebFlux entry point that composes downstream microservices and offers `/api/gateway/*` APIs.
- **Orders, Billing, Notification, Analytics** – Spring Boot services backed by Postgres, RabbitMQ, and Redis.
- **Catalog** – Quarkus product service that feeds the catalog UI and integrates with the gateway.
- **Webapp** – React + Vite SPA consumed via `VITE_API_BASE_URL`.
- **Observability stack** – Prometheus/Grafana resources (manifests + dashboards) scrape JVM + HTTP metrics for each service.

## Architecture

```
           ┌────────────┐
           │ React UI   │
           │ (webapp)   │
           └─────┬──────┘
                 ▼
        ┌───────────────────────┐
        │ Gateway Service (8080) │
        └─────┬─────┬────┬──────┘
              │     │    │
              ▼     ▼    ▼
     ┌──────────┐ ┌──────────┐ ┌────────────┐
     │ Orders   │ │ Catalog  │ │ Billing    │
     │ (8081)   │ │ (8085)   │ │ (8082)     │
     └────┬─────┘ └────┬─────┘ └────┬───────┘
          │            │            │
          ▼            ▼            ▼
     PostgreSQL    PostgreSQL    PostgreSQL
     Redis         (shared via    (shared via
     RabbitMQ       Kafka/AMQP)    analytics)
```

The gateway forwards HTTP traffic to the Spring Boot services (orders, billing, notification, analytics) plus the Quarkus catalog service, while shared infrastructure (Postgres, Redis, RabbitMQ) supports persistence, caching, and messaging.

## Quickstart (Local)

1. **Prerequisites**
   - Docker Desktop / Docker Engine + Compose plugin
   - Java 21 / Maven (build Java services)
   - Node.js (React UI via Vite)

2. **Start the stack**

```bash
cd infra/local
docker compose up --build
```

3. **Access the platform**

```text
- React UI:            http://localhost:5173 (run `cd webapp && npm run dev`)
- Gateway health:      http://localhost:8080/api/gateway/status
- Orders service:      http://localhost:8081/actuator/health
- RabbitMQ UI:         http://localhost:15672
- Grafana (when enabled via infra/observability): http://localhost:3000
```

4. **Seed demo data**

```bash
curl -X POST http://localhost:8080/api/gateway/seed
```

The UI uses `VITE_API_BASE_URL` (default `http://localhost:8080`). Adjust that env var when running the SPA against a different gateway host.

## Containerized Builds/Tests (Baseline JDK)

Use Docker to run backend builds/tests against a specific Java baseline, independent of the host JDK.

```bash
./scripts/run-build-in-jdk.sh 17
./scripts/run-tests-in-jdk.sh 17
```

## API Overview

- `GET /api/gateway/status` – lightweight service health.
- `GET /api/gateway/orders` – paged list of orders (filters via `page`, `size`).
- `POST /api/gateway/orders` – place a new order.
- `PUT /api/gateway/orders/{id}` – update order metadata/items.
- `POST /api/gateway/orders/{id}/confirm` – confirm payment intent.
- `POST /api/gateway/orders/{id}/cancel` – cancel a new order.
- `GET /api/gateway/orders/latest` – dashboard-friendly recents.
- `GET /api/gateway/catalog` – list products and filter by `category`/`search`.
- `POST /api/gateway/catalog` – create or edit catalog entries.
- `POST /api/gateway/seed` – seed catalog + orders data from a deterministic payload.
- `GET /api/gateway/system/status` – aggregate status from each downstream service.

Other services expose their native endpoints (`/api/orders/*`, `/api/catalog/*`, etc.) for deeper debugging.

## Observability

- Deploy the Prometheus/Grafana stack referenced under `infra/observability/k8s/` (`ServiceMonitor` YAMLs) once you have `kube-prometheus-stack`.
- Import the dashboard JSON at `infra/observability/grafana/acmecorp-jvm-http-overview.json` into Grafana for JVM/HTTP telemetry.
- Each Spring Boot service exposes `/actuator/prometheus`, `/actuator/health`, and `/actuator/info`.
- The Quarkus catalog service exposes `/q/metrics`.
- Grafana sees metrics via the service monitors that scrape the above endpoints every 15s.

## Database Performance: Hibernate N+1

- **Demo endpoint**: `GET /api/orders/demo/nplus1?limit=N` runs `OrderService.listOrdersNPlusOneDemo(limit)` which fetches orders via `orderRepository.findAll(...)` and maps `OrderResponse.from(order)` without preloading `items`. This produces the classic 1 (orders) + N (items) queries.
- **Optimized flow**: `listOrders` and `latestOrders` now call `preloadItems(...)`, which collects the returned IDs and runs `OrderRepository.findAllWithItemsByIds(ids)` (a `left join fetch`), so only the orders query plus one join-fetch covers all items.
- **Regression guard**: `OrderServiceQueryCountTest` seeds 10 orders × 5 items, enables `hibernate.generate_statistics` (see `services/spring-boot/orders-service/src/test/resources/application-test.yml` for the H2 profile), and asserts that the optimized path runs no more than 3 SQL statements. Run it via:

```bash
cd services/spring-boot/orders-service
mvn test -Dtest=OrderServiceQueryCountTest
```

The test ensures the fixed flow cannot regresses into N+1 while developers can still invoke `/api/orders/demo/nplus1` to observe the pathological behavior.

## Learning Path: Season 1 (8×10 min)

1. Episode 1 – Foundation: Platform, Spring Boot & Quarkus on Kubernetes  
2. Episode 2 – JVM Deep Dive: Virtual Threads, N+1, Profiling  
3. Episode 3 – Deploying & Optimizing on EKS Auto Mode  
4. Episode 4 – Observability with Prometheus & Grafana  
5. Episode 5 – Reactive Gateway & API Composition  
6. Episode 6 – Catalog and Orders Management Workflows  
7. Episode 7 – Automation, GitOps, and Helm Deployments  
8. Episode 8 – Monitoring, Alerts, and Runbook Drills  

## Troubleshooting

- **Ports in use** – stop conflicting containers/processes if `docker compose` fails to bind 8080–8085, 5432, 6379, or 5672.
- **Docker resource limits** – bump CPU/memory if the JVMs or PostgreSQL repeatedly restart under load.
- **Clean rebuild** – run `docker compose down --volumes` followed by `docker compose up --build` and `mvn -pl services/spring-boot/orders-service clean test` when caches cause inconsistent data.
- **UI not talking to gateway** – ensure `VITE_API_BASE_URL` matches the gateway URL before running `npm run dev`.

## License / Contributing

This repository does not publish a formal `LICENSE` or `CONTRIBUTING.md`; please coordinate with the AcmeCorp maintainers before sharing or extending the code.
