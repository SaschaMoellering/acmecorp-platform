# Episode 4 — Observability: Metrics, Health & Signals

## Opening – Observability is not optional

Up to this point, we've focused on structure and behavior. In Episode 1, we defined the shape of the system. In Episode 2, we made it run locally and treated local development and CI as equal constraints. In Episode 3, we introduced strict API boundaries and error containment.

Now we arrive at the question that determines whether this system can be operated at all: How do we know what the system is doing?

Most teams look at metrics only when something is already broken. At that point, observability turns into forensics. In this episode, we take a different approach. Observability is not optional. It must be designed into the system from day one.

### Health, readiness, and liveness
[SHOW: Terminal - curl http://localhost:8081/actuator/health]

The word "health" is often overloaded. Not all health checks mean the same thing. This distinction becomes critical once we run on Kubernetes or behind a load balancer.

Liveness answers: Is the process alive? 
Readiness answers: Can this instance handle traffic right now? 
Health is often used as an umbrella term that hides these differences.

A service can be alive but not ready. Routing traffic to an unready service is one of the fastest ways to create cascading failures. This is exactly why Episode 2 emphasized startup order and readiness signals with health checks in Docker Compose.

### Readiness as a traffic gate
[SHOW: docker-compose.yml - depends_on with service_healthy]

Readiness is not primarily a monitoring signal. It's a traffic gate. When readiness is false, load balancers must stop sending traffic, and Kubernetes must not route requests to the instance.

Look at our Docker Compose file - every service has a depends_on with condition: service_healthy. The orders service won't start until Postgres, RabbitMQ, and Redis are all healthy. The gateway won't start until all backend services are healthy. This allows the system to absorb slow startups, dependency outages, and restore or warmup phases.

Without readiness, every transient problem becomes visible to users immediately.

### From concepts to real code
[SHOW: IntelliJ IDEA – services/spring-boot/orders-service]

Observability only exists if signals are produced by real application code. Concepts alone are not observable. So let's look at a concrete example. We'll use the Orders Service and start at the very edge - the REST API layer.

### OrdersController – the API surface
[SHOW: IntelliJ – OrdersController.java]

Let's look at the OrdersController. This controller is the REST API layer for our orders microservice. It's annotated with @RestController and @RequestMapping("/api/orders"), which makes it handle all requests under /api/orders. This is the boundary where external requests enter the Orders Service.

### CRUD and lifecycle operations
[SHOW: IntelliJ – scroll through controller methods]

The controller provides standard CRUD operations - POST to create orders, GET to retrieve them, PUT to update, DELETE to remove. We also support pagination and filtering via query parameters.

Beyond basic CRUD, there are explicit business operations - confirm to advance the order lifecycle, cancel to roll it back, and a history endpoint that shows how an order's state changed over time. This is a realistic API surface, not a toy example.

### The interesting part: no metrics code
[SHOW: IntelliJ – highlight controller code]

Now here's the interesting part. There is no metrics code in this controller. No timers, no counters, no manual instrumentation. And that's intentional.

Zero-code HTTP metrics with Spring Boot Actuator
[SHOW: IntelliJ – pom.xml - spring-boot-starter-actuator dependency]

When we add the spring-boot-starter-actuator dependency, something important happens. Every HTTP request to every endpoint is instrumented automatically. Spring Boot, together with Micrometer, tracks request counts, response times, error rates, and HTTP status codes. All of this happens without writing a single line of metrics code.

[SHOW: application.yml - management.endpoints configuration]

In our application configuration, we expose the Prometheus endpoint. This endpoint produces metrics in a format that Prometheus and Grafana can consume directly. The application doesn't know about dashboards. It only exposes signals.

### What metrics do we get?
[SHOW: Terminal – curl http://localhost:8081/actuator/prometheus | grep http_server_requests]

For every HTTP endpoint, we automatically get metrics like http_server_requests_seconds_count for request count, http_server_requests_seconds_sum for total time spent, and http_server_requests_seconds_max for the slowest request.

Each metric is tagged with the URI, the HTTP method, the status code, and the outcome. This allows us to slice and aggregate metrics by endpoint, by success versus failure, or by any combination.

### JVM metrics for free
[SHOW: Terminal – curl http://localhost:8081/actuator/prometheus | grep jvm_]

In addition to HTTP metrics, we also get JVM metrics automatically. This includes heap and non-heap memory usage, garbage collection pauses, thread counts, and CPU usage. Again, without writing any metrics code.

### The observability stack
[SHOW: Terminal - cd infra/local && ls]

Now let's look at how we collect and visualize these metrics. We have two Docker Compose files - the main one for the application services, and docker-compose.observability.yml for the observability stack.

### [SHOW: docker-compose.observability.yml]

The observability stack includes three main components: Prometheus for metrics collection, Alertmanager for alert routing, and Grafana for visualization. We also have k6 for load testing, but that's optional and runs under a profile.

### Prometheus - metrics collection
[SHOW: observability/prometheus/prometheus.yml]

Prometheus is configured to scrape metrics from all our services every 15 seconds. Look at the scrape configs - we have a job for each service. Spring Boot services are scraped at /actuator/prometheus, and the Quarkus catalog service is scraped at /q/metrics. Each target gets an application label so we can filter metrics by service in Grafana.

Prometheus also loads alert rules from the rules directory and sends alerts to Alertmanager. We're storing 7 days of metrics history locally.

### Alert rules
[SHOW: observability/prometheus/rules/acmecorp-alerts.yml]

We've defined three alert rules. AcmeCorpServiceDown fires if any service is unreachable for 30 seconds. GatewayHigh5xxRate fires if the gateway's 5xx error rate exceeds 2% for 2 minutes. And JvmThreadsHigh fires if any service has more than 300 live threads for 5 minutes.

These aren't just examples - they're real alerts that would catch actual problems. A service going down, error rates spiking, or thread leaks building up.

### Alertmanager - alert routing
[SHOW: observability/alertmanager/alertmanager.yml]

Alertmanager receives alerts from Prometheus and routes them to receivers. In our local setup, we're using a default receiver with no specific routing. In production, you'd configure this to send alerts to Slack, PagerDuty, or email based on severity and application.

The important part is the grouping - alerts are grouped by alertname and application, with a 10-second wait before sending and a 2-hour repeat interval. This prevents alert storms.

### Grafana - visualization
[SHOW: observability/grafana/provisioning/]

Grafana is configured through provisioning files. The datasource configuration automatically connects Grafana to Prometheus. The dashboards configuration loads all our pre-built dashboards from the dashboards directory.

[SHOW: Terminal - ls observability/grafana/dashboards/]

We have four dashboards: the platform overview, gateway traffic breakdown, JVM garbage collection breakdown, and JVM thread and memory breakdown. These aren't generic dashboards - they're specifically designed for the AcmeCorp platform.

### Starting the observability stack
[SHOW: Terminal - docker compose -f docker-compose.yml -f docker-compose.observability.yml up -d]

To start everything, we use Docker Compose with both files. The -f flag lets us compose multiple files together. This starts the application services from the main file and the observability stack from the observability file.

[SHOW: Terminal - docker compose ps]

Now we have everything running - six application services, three infrastructure services, and three observability services. Twelve containers total, all networked together.

### Seeing metrics in action
[SHOW: Browser - http://localhost:9090]

Let's open Prometheus at localhost:9090. We can query metrics directly here. Let's search for http_server_requests_seconds_count and filter by application equals gateway-service. We see the request count for every endpoint in the gateway, broken down by method, status, and URI.

[SHOW: Prometheus - Graph view]

We can graph this over time and see request patterns. This is raw metrics - useful for debugging, but not great for monitoring.

### Grafana dashboards
[SHOW: Browser - http://localhost:3000 - login with admin/admin]

Now let's open Grafana at localhost:3000. Login is admin/admin. Once we're in, we can see our AcmeCorp folder with four dashboards.

[SHOW: AcmeCorp Platform Overview dashboard]

The platform overview shows services up, gateway requests per second, gateway 5xx rate, gateway latency percentiles, JVM heap usage by application, and live threads by application. This is a single pane of glass for the entire platform.

Look at the services up panel - it's showing 6, which means all our services are healthy. The gateway RPS shows current traffic. The 5xx rate is at 0%, which is good. Latency is low. Heap usage is stable. Thread counts are reasonable.

### Demonstrating a performance problem
[SHOW: Terminal - curl http://localhost:8080/api/gateway/orders/latest]

Let's generate some traffic. We'll call the latest orders endpoint through the gateway. This is the optimized endpoint that uses join fetch to avoid N+1 queries.

[SHOW: Grafana - watch metrics update]

Watch the dashboard - request rate increases, latency stays low. This is normal behavior.

[SHOW: Terminal - curl "http://localhost:8081/api/orders/demo/nplus1?limit=20"]

Now let's call the N+1 demo endpoint directly on the orders service. This intentionally creates a performance problem by fetching orders and items with separate queries.

[SHOW: Grafana - watch latency spike]

Look at the dashboard - latency spikes immediately. We can see exactly which service is degrading and how it affects response times. The metrics reflect the problem instantly.

### Gateway traffic breakdown
[SHOW: Gateway Traffic Breakdown dashboard]

The gateway traffic breakdown dashboard shows request rate by URI, error rate by URI, and latency by URI. This lets us see which endpoints are getting the most traffic, which ones are failing, and which ones are slow.

If we had a problem with a specific endpoint, this dashboard would show us exactly where to look.

### JVM deep dives
[SHOW: JVM GC Breakdown dashboard]

The JVM GC breakdown dashboard shows garbage collection pauses, GC time percentage, heap usage before and after GC, and allocation rates. This is critical for understanding memory behavior and tuning GC settings.

[SHOW: JVM Thread Memory Breakdown dashboard]

The thread and memory breakdown shows thread counts by state, heap and non-heap memory, memory pool usage, and class loading. This helps diagnose thread leaks, memory leaks, and classloader issues.

### Metrics as signals, not answers
[SHOW: Back to Platform Overview]

Metrics don't explain why something happens. They tell us where to look. In the N+1 example, the metrics pointed us directly at the problematic endpoint. That's the power of observability - it surfaces problems immediately and guides investigation.

### Dashboards as hypotheses
Dashboards are not truth. They're hypotheses. A dashboard says: "If something goes wrong, this is where we should look first." Good dashboards align with API boundaries from Episode 3. That's why we have a gateway-specific dashboard - the gateway is our API boundary, so that's where we monitor first.

### Why observability comes before performance
Without observability, performance discussions are guesswork, optimizations are risky, and regressions go unnoticed. With observability in place, we finally have something we can trust.

We can see the N+1 problem in metrics. We can measure the improvement when we fix it. We can write tests that verify the fix doesn't regress. This is measurable, repeatable, and verifiable.

### Closing – Seeing before fixing
Observability isn't about dashboards. It's about visibility. Only when we can see the system clearly can we begin to change it safely.

In the next episode, we'll use these signals to talk about performance. Not as theory, but as something we can measure, reason about, and improve. We'll dive deep into the N+1 problem, look at virtual threads, and explore JVM profiling. But we can only do that because we have observability in place first.