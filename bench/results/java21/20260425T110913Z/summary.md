# Benchmark results for java21

- Scenario: mixed
- Branch mode: branch-comparison
- Startup: 10.854s
- Startup raw: 10854 ms
- Load ready delay after health: 7980 ms
- Startup to load-ready: 18834 ms
- Health endpoint: http://localhost:8080/api/gateway/status
- Load target: GET http://localhost:8080/api/gateway/orders
- Scenario metadata: [scenario.json](scenario.json)
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 6647.25 req/s (p50=3.46ms, p95=5.78ms, p99=6.67ms, errors=na)
- Memory snapshot: analytics-service:345.7MiB, billing-service:387.1MiB, catalog-service:294.9MiB, gateway-service:560.8MiB, notification-service:366.7MiB, orders-service:581.7MiB, postgres:94.43MiB, rabbitmq:142.4MiB, redis:4.398MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
- DB query count: not collected by the current harness
