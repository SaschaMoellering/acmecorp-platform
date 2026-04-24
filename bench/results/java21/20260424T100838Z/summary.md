# Benchmark results for java21

- Scenario: mixed
- Branch mode: branch-comparison
- Startup: 11.120s
- Startup raw: 11120 ms
- Load ready delay after health: 7942 ms
- Startup to load-ready: 19062 ms
- Health endpoint: http://localhost:8080/api/gateway/status
- Load target: GET http://localhost:8080/api/gateway/orders
- Scenario metadata: [scenario.json](scenario.json)
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 6722.42 req/s (p50=3.41ms, p95=5.79ms, p99=6.75ms, errors=na)
- Memory snapshot: analytics-service:384.5MiB, billing-service:393.9MiB, catalog-service:289.6MiB, gateway-service:555.8MiB, notification-service:400.7MiB, orders-service:520MiB, postgres:157.6MiB, rabbitmq:177.7MiB, redis:22.02MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
- DB query count: not collected by the current harness
