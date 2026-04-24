# Benchmark results for java21

- Scenario: mixed
- Branch mode: branch-comparison
- Startup: 9.624s
- Startup raw: 9624 ms
- Load ready delay after health: 8474 ms
- Startup to load-ready: 18098 ms
- Health endpoint: http://localhost:8080/api/gateway/status
- Load target: GET http://localhost:8080/api/gateway/orders
- Scenario metadata: [scenario.json](scenario.json)
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 6408.96 req/s (p50=3.57ms, p95=6.13ms, p99=7.13ms, errors=na)
- Memory snapshot: analytics-service:357.4MiB, billing-service:372.3MiB, catalog-service:272.7MiB, gateway-service:534.7MiB, notification-service:384.2MiB, orders-service:543.8MiB, postgres:93.72MiB, rabbitmq:140.5MiB, redis:3.902MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
- DB query count: not collected by the current harness
