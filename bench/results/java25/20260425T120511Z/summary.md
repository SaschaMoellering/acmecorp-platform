# Benchmark results for java25

- Scenario: mixed
- Branch mode: branch-comparison
- Startup: 11.574s
- Startup raw: 11574 ms
- Load ready delay after health: 4788 ms
- Startup to load-ready: 16362 ms
- Health endpoint: http://localhost:8080/api/gateway/status
- Load target: GET http://localhost:8080/api/gateway/orders
- Scenario metadata: [scenario.json](scenario.json)
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 5499.2 req/s (p50=4.18ms, p95=7.13ms, p99=8.29ms, errors=na)
- Memory snapshot: analytics-service:374.6MiB, billing-service:385.8MiB, catalog-service:272.9MiB, gateway-service:539.1MiB, notification-service:370.1MiB, orders-service:711.7MiB, postgres:94.34MiB, rabbitmq:138.9MiB, redis:4.398MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
- DB query count: not collected by the current harness
