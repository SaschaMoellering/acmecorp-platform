# Benchmark results for java21

- Scenario: mixed
- Branch mode: branch-comparison
- Startup: 12.219s
- Startup raw: 12219 ms
- Load ready delay after health: 11656 ms
- Startup to load-ready: 23875 ms
- Health endpoint: http://localhost:8080/api/gateway/status
- Load target: GET http://localhost:8080/api/gateway/orders
- Scenario metadata: [scenario.json](scenario.json)
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 5751.4 req/s (p50=3.90ms, p95=7.69ms, p99=9.30ms, errors=na)
- Memory snapshot: analytics-service:362.5MiB, billing-service:369.3MiB, catalog-service:282.4MiB, gateway-service:561.1MiB, notification-service:370.5MiB, orders-service:521.3MiB, postgres:91.25MiB, rabbitmq:140.8MiB, redis:3.895MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
- DB query count: not collected by the current harness
