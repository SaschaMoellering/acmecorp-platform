# Episode 4 — Observability: Metrics, Health & Signals

## Opening – Observability is not optional

Up to this point, we've focused on structure and behavior. In Episode 1, we defined the shape of the system. In Episode 2, we made it run locally and treated local development and CI as equal constraints. In Episode 3, we introduced strict API boundaries and error containment.

Now we arrive at the question that determines whether this system can be operated at all: How do we know what the system is doing?

Most teams look at metrics only when something is already broken. At that point, observability turns into forensics. In this episode, we take a different approach. Observability is not optional. It must be designed into the system from day one.

---

## Health, readiness, and liveness – Three different questions
[SHOW: Terminal - curl http://localhost:8081/actuator/health]

The word "health" is often overloaded. Not all health checks mean the same thing. This distinction becomes critical once we run on Kubernetes or behind a load balancer.

Liveness answers: Is the process alive? If not, restart it.

Readiness answers: Can this instance handle traffic right now? If not, stop routing to it.

Health is often used as an umbrella term that hides these differences.

A service can be alive but not ready. Maybe it's warming up caches. Maybe it's waiting for a database connection pool to initialize. Maybe it's restoring state from a checkpoint. Routing traffic to an unready service is one of the fastest ways to create cascading failures.

This is exactly why Episode 2 emphasized startup order and readiness signals with health checks in Docker Compose.

---

## Readiness as a traffic gate – Not just monitoring
[SHOW: docker-compose.yml - depends_on with service_healthy]

Let me open the docker-compose file and show you something important. Look at the orders-service definition. It has a `depends_on` section with three dependencies: postgres, rabbitmq, and redis. Each one has `condition: service_healthy`.

This means the orders-service container won't start until Postgres, RabbitMQ, and Redis all report healthy. Now look at the gateway-service. It depends on all five backend services—orders, billing, notification, analytics, and catalog. The gateway won't start until all of them are running.

This is readiness as a traffic gate. The system absorbs slow startups, dependency outages, and warmup phases. Without readiness, every transient problem becomes visible to users immediately.

Now let me show you what a health check actually looks like. I'll curl the orders-service health endpoint.

```bash
curl http://localhost:8081/actuator/health
```

We get back a JSON response with status UP, and details about the components—database, RabbitMQ, diskSpace, ping. Each component reports its own health, and the overall status is UP only if all components are healthy.

This is what the docker-compose health checks are calling. When this endpoint returns status UP, the service is marked as healthy and traffic can flow.

---

## From concepts to real code – The Orders Service
[SHOW: IntelliJ IDEA – services/spring-boot/orders-service]

Observability only exists if signals are produced by real application code. Concepts alone are not observable. So let's look at a concrete example. We'll use the Orders Service and start at the very edge—the REST API layer.

Let me open the Orders Service in IntelliJ. This is a Spring Boot microservice with a standard package structure: api for REST controllers, domain for entities, repository for data access, service for business logic, and web for request/response DTOs.

---

## OrdersController – The API surface

Let me open OrdersController. This controller is the REST API layer for our orders microservice. It's annotated with `@RestController` and `@RequestMapping("/api/orders")`, which makes it handle all requests under `/api/orders`. This is the boundary where external requests enter the Orders Service.

Look at the methods. We have `createOrder` for POST requests, `getOrder` for fetching a single order by ID, `listOrders` for paginated queries with optional filters, `updateOrder` for PUT requests, and `deleteOrder` for DELETE requests.

Beyond basic CRUD, there are explicit business operations. `confirm` advances the order lifecycle. `cancel` rolls it back. `history` shows how an order's state changed over time. This is a realistic API surface, not a toy example.

Now here's the interesting part. There is no metrics code in this controller. No timers, no counters, no manual instrumentation. And that's intentional.

---

## Zero-code HTTP metrics with Spring Boot Actuator

Let me open the pom.xml file. Look at the dependencies. We have `spring-boot-starter-web` for the REST API, `spring-boot-starter-data-jpa` for database access, and `spring-boot-starter-actuator` for observability.

When we add the actuator dependency, something important happens. Every HTTP request to every endpoint is instrumented automatically. Spring Boot, together with Micrometer, tracks request counts, response times, error rates, and HTTP status codes. All of this happens without writing a single line of metrics code.

Now let me open the application.yml file. Look at the management section. We're exposing three endpoints: health, info, and prometheus. The health endpoint is what we just curled. The prometheus endpoint produces metrics in a format that Prometheus and Grafana can consume directly.

The application doesn't know about dashboards. It only exposes signals.

---

## What metrics do we get? – Seeing the raw data

Let me curl the prometheus endpoint and grep for http_server_requests.

```bash
curl -s http://localhost:8081/actuator/prometheus | grep http_server_requests
```

Look at the output. For every HTTP endpoint, we automatically get metrics like `http_server_requests_seconds_count` for request count, `http_server_requests_seconds_sum` for total time spent, and `http_server_requests_seconds_max` for the slowest request.

Each metric is tagged with the URI, the HTTP method, the status code, and the outcome. This allows us to slice and aggregate metrics by endpoint, by success versus failure, or by any combination.

Now let me grep for jvm metrics.

```bash
curl -s http://localhost:8081/actuator/prometheus | grep jvm_memory
```

We also get JVM metrics automatically. Heap and non-heap memory usage, garbage collection pauses, thread counts, CPU usage. Again, without writing any metrics code.

This is the foundation of observability. The application produces signals. Something else collects and visualizes them.

---

## The observability stack – Prometheus, Alertmanager, Grafana

Now let's look at how we collect and visualize these metrics. Let me navigate to the infra/local directory.

```bash
cd infra/local
ls
```

We have two Docker Compose files. The main one, `docker-compose.yml`, defines the application services. The second one, `docker-compose.observability.yml`, defines the observability stack.

Let me open the observability compose file. We have three main components: Prometheus for metrics collection, Alertmanager for alert routing, and Grafana for visualization. We also have k6 for load testing, but that's optional and runs under a profile.

---

## Prometheus – Metrics collection and scraping

Let me open the Prometheus configuration file.

```bash
cat observability/prometheus/prometheus.yml
```

Prometheus is configured to scrape metrics from all our services every 15 seconds. Look at the scrape configs. We have a job for each service. Spring Boot services are scraped at `/actuator/prometheus`, and the Quarkus catalog service is scraped at `/q/metrics`. Each target gets an application label so we can filter metrics by service in Grafana.

Prometheus also loads alert rules from the rules directory and sends alerts to Alertmanager. We're storing 7 days of metrics history locally.

---

## Alert rules – Catching real problems

Let me look at the alert rules.

```bash
cat observability/prometheus/rules/acmecorp-alerts.yml
```

We've defined three alert rules. `AcmeCorpServiceDown` fires if any service is unreachable for 30 seconds. `GatewayHigh5xxRate` fires if the gateway's 5xx error rate exceeds 2% for 2 minutes. `JvmThreadsHigh` fires if any service has more than 300 live threads for 5 minutes.

These aren't just examples—they're real alerts that would catch actual problems. A service going down, error rates spiking, or thread leaks building up.

---

## Alertmanager – Alert routing and grouping

Let me look at the Alertmanager configuration.

```bash
cat observability/alertmanager/alertmanager.yml
```

Alertmanager receives alerts from Prometheus and routes them to receivers. In our local setup, we're using a default receiver with no specific routing. In production, you'd configure this to send alerts to Slack, PagerDuty, or email based on severity and application.

The important part is the grouping. Alerts are grouped by alertname and application, with a 10-second wait before sending and a 2-hour repeat interval. This prevents alert storms.

---

## Grafana – Visualization and dashboards

Let me look at the Grafana provisioning configuration.

```bash
ls observability/grafana/provisioning/
```

We have two directories: datasources and dashboards. The datasource configuration automatically connects Grafana to Prometheus. The dashboards configuration loads all our pre-built dashboards from the dashboards directory.

```bash
ls observability/grafana/dashboards/
```

We have four dashboards: the platform overview, gateway traffic breakdown, JVM garbage collection breakdown, and JVM thread and memory breakdown. These aren't generic dashboards—they're specifically designed for the AcmeCorp platform.

---

## Starting the observability stack – Composing multiple files

Let me start everything. We use Docker Compose with both files. The `-f` flag lets us compose multiple files together.

```bash
docker compose -f docker-compose.yml -f docker-compose.observability.yml up -d
```

This starts the application services from the main file and the observability stack from the observability file. Let me check the status.

```bash
docker compose ps
```

Now we have everything running. Six application services, three infrastructure services, and three observability services. Twelve containers total, all networked together.

---

## Seeing metrics in action – Prometheus UI

Let me open Prometheus in the browser at localhost:9090. This is the Prometheus UI. I can query metrics directly here.

Let me search for `http_server_requests_seconds_count` and filter by application equals gateway-service. We see the request count for every endpoint in the gateway, broken down by method, status, and URI.

I can switch to the graph view and see request patterns over time. This is raw metrics—useful for debugging, but not great for monitoring.

---

## Grafana dashboards – The single pane of glass

Now let me open Grafana at localhost:3000. Login is admin/admin. Once we're in, we can see our AcmeCorp folder with four dashboards.

Let me open the Platform Overview dashboard. This shows services up, gateway requests per second, gateway 5xx rate, gateway latency percentiles, JVM heap usage by application, and live threads by application. This is a single pane of glass for the entire platform.

Look at the services up panel—it's showing 6, which means all our services are healthy. The gateway RPS shows current traffic. The 5xx rate is at 0%, which is good. Latency is low. Heap usage is stable. Thread counts are reasonable.

---

## Application walkthrough – Using the actual system

Before we demonstrate a performance problem, let me show you the actual application running. We have a web UI that interacts with the platform through the gateway.

Let me open the application at localhost:8080. This is the AcmeCorp platform web interface. It's a simple React application that calls the gateway API.

On the home page, we can see the system status. All services are up. We can see the catalog of products, and we can create orders.

Let me click on the catalog. This calls `/api/gateway/catalog` and returns a list of products. Each product has an ID, name, description, price, and category. This data comes from the Quarkus catalog service, but the client doesn't know that—it only talks to the gateway.

Now let me create an order. I'll select a product, enter a customer email, and submit. This calls `/api/gateway/orders` with a POST request. The gateway forwards it to the orders service, which creates the order in the database, publishes an event to RabbitMQ, and returns the order response.

The order appears in the orders list. I can click on it to see the details. This calls `/api/gateway/orders/{id}` with the `includeHistory` parameter. The gateway fetches the order from the orders service and the invoices from the billing service, then combines them into a single response.

This is the system in action. The web UI talks to the gateway. The gateway talks to the backend services. The backend services talk to the database and message queue. And all of this is instrumented automatically.

---

## Generating traffic and watching metrics

Now let's generate some traffic and watch the metrics in action. Let me call the orders endpoint through the gateway.

```bash
curl http://localhost:8080/api/gateway/orders/latest
```

Let me switch back to Grafana and watch the dashboard. Request rate increases, latency stays low. We can see the metrics updating in real time—request counts incrementing, latency percentiles staying stable, error rates at zero.

Let me make a few more requests to different endpoints.

```bash
curl http://localhost:8080/api/gateway/catalog
curl http://localhost:8080/api/gateway/orders?page=0&size=10
```
Generating traffic and watching metrics
Watch the dashboard. Each request shows up immediately. The gateway RPS increases. The latency distribution updates. The services remain healthy. This is observability in action—we can see exactly what the system is doing, in real time, without adding any custom instrumentation.

---

## Gateway traffic breakdown – Drilling into specific endpoints

Let me open the Gateway Traffic Breakdown dashboard. This shows request rate by URI, error rate by URI, and latency by URI. This lets us see which endpoints are getting the most traffic, which ones are failing, and which ones are slow.

If we had a problem with a specific endpoint, this dashboard would show us exactly where to look. We can see that `/api/gateway/orders` is getting the most traffic, and the latency is consistent. The `/api/gateway/catalog` endpoint is also active, with low latency.

---

## JVM deep dives – Understanding memory and threads

Let me open the JVM GC Breakdown dashboard. This shows garbage collection pauses, GC time percentage, heap usage before and after GC, and allocation rates. This is critical for understanding memory behavior and tuning GC settings.

We can see that GC pauses are short—under 10 milliseconds. The GC time percentage is low, which means we're not spending much time in garbage collection. Heap usage is stable, with regular sawtooth patterns showing allocation and collection.

Now let me open the JVM Thread Memory Breakdown dashboard. This shows thread counts by state, heap and non-heap memory, memory pool usage, and class loading. This helps diagnose thread leaks, memory leaks, and classloader issues.

We can see that thread counts are stable. Most threads are in the RUNNABLE or TIMED_WAITING state, which is normal. Heap memory is well within limits. Non-heap memory is stable, which means we're not leaking metaspace or code cache.

---

## Metrics as signals, not answers

Metrics don't explain why something happens. They tell us where to look. If we see latency spike on a specific endpoint, the metrics point us directly to that endpoint. If we see error rates increase, the metrics show us which service is failing. That's the power of observability—it surfaces problems immediately and guides investigation.

Metrics are signals. They say: "Something changed here. Go look." They don't tell you what to do. They don't explain the root cause. But they give you a starting point.

---

## Dashboards as hypotheses – Aligning with boundaries

Dashboards are not truth. They're hypotheses. A dashboard says: "If something goes wrong, this is where we should look first."

Good dashboards align with API boundaries from Episode 3. That's why we have a gateway-specific dashboard—the gateway is our API boundary, so that's where we monitor first. If the gateway is slow, we drill into the backend services. If the gateway is returning errors, we check which backend service is failing.

The platform overview dashboard gives us the big picture. The gateway dashboard gives us the API boundary. The JVM dashboards give us the runtime behavior. Each dashboard answers a specific question.

---

## Why observability comes before performance

Without observability, performance discussions are guesswork. Optimizations are risky. Regressions go unnoticed.

With observability in place, we finally have something we can trust. We can see when latency increases. We can measure the impact of changes. We can write tests that verify behavior doesn't regress. This is measurable, repeatable, and verifiable.

Observability is the foundation. Performance optimization is what we build on top of it.

---

## Conclusion

Observability isn't about dashboards. It's about visibility. Only when we can see the system clearly can we begin to change it safely.

In the next episode, we'll use these signals to talk about performance. Not as theory, but as something we can measure, reason about, and improve. We'll dive deep into database query optimization, look at the N+1 problem, explore virtual threads, and examine JVM profiling. But we can only do that because we have observability in place first.

You can't fix what you can't see. Now we can see.
