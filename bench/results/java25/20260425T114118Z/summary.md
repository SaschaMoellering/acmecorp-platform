# Benchmark results for java25

- Scenario: mixed
- Branch mode: branch-comparison
- Startup: 11.946s
- Startup raw: 11946 ms
- Load ready delay after health: 5294 ms
- Startup to load-ready: 17240 ms
- Health endpoint: http://localhost:8080/api/gateway/status
- Load target: GET http://localhost:8080/api/gateway/orders
- Scenario metadata: [scenario.json](scenario.json)
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 5452.83 req/s (p50=4.21ms, p95=7.30ms, p99=8.54ms, errors=na)
- Memory snapshot: analytics-service:360.9MiB, billing-service:378.5MiB, catalog-service:243.8MiB, gateway-service:419MiB, notification-service:385.9MiB, orders-service:627.6MiB, postgres:93.98MiB, rabbitmq:138.5MiB, redis:3.906MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
- DB query count: not collected by the current harness
