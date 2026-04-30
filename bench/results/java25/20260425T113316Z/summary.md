# Benchmark results for java25

- Scenario: mixed
- Branch mode: branch-comparison
- Startup: 12.435s
- Startup raw: 12435 ms
- Load ready delay after health: 5924 ms
- Startup to load-ready: 18359 ms
- Health endpoint: http://localhost:8080/api/gateway/status
- Load target: GET http://localhost:8080/api/gateway/orders
- Scenario metadata: [scenario.json](scenario.json)
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 5530.59 req/s (p50=4.15ms, p95=7.15ms, p99=8.35ms, errors=na)
- Memory snapshot: analytics-service:422.8MiB, billing-service:415MiB, catalog-service:285.6MiB, gateway-service:626.8MiB, notification-service:404.8MiB, orders-service:701.8MiB, postgres:94.45MiB, rabbitmq:178.4MiB, redis:4.152MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
- DB query count: not collected by the current harness
