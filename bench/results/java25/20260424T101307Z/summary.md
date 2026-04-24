# Benchmark results for java25

- Scenario: mixed
- Branch mode: branch-comparison
- Startup: 12.272s
- Startup raw: 12272 ms
- Load ready delay after health: 5518 ms
- Startup to load-ready: 17790 ms
- Health endpoint: http://localhost:8080/api/gateway/status
- Load target: GET http://localhost:8080/api/gateway/orders
- Scenario metadata: [scenario.json](scenario.json)
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 3754.29 req/s (p50=6.00ms, p95=12.05ms, p99=14.70ms, errors=na)
- Memory snapshot: analytics-service:385.7MiB, billing-service:413.4MiB, catalog-service:273.4MiB, gateway-service:630.8MiB, notification-service:0B, orders-service:754.6MiB, postgres:94.48MiB, rabbitmq:138MiB, redis:3.648MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
- DB query count: not collected by the current harness
