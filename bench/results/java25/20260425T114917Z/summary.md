# Benchmark results for java25

- Scenario: mixed
- Branch mode: branch-comparison
- Startup: 10.589s
- Startup raw: 10589 ms
- Load ready delay after health: 6127 ms
- Startup to load-ready: 16716 ms
- Health endpoint: http://localhost:8080/api/gateway/status
- Load target: GET http://localhost:8080/api/gateway/orders
- Scenario metadata: [scenario.json](scenario.json)
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 5452.16 req/s (p50=4.21ms, p95=7.24ms, p99=8.42ms, errors=na)
- Memory snapshot: analytics-service:380.3MiB, billing-service:377.4MiB, catalog-service:279.5MiB, gateway-service:565.4MiB, notification-service:368.3MiB, orders-service:504.1MiB, postgres:94.54MiB, rabbitmq:135.4MiB, redis:4.152MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
- DB query count: not collected by the current harness
