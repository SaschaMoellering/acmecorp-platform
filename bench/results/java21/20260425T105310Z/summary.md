# Benchmark results for java21

- Scenario: mixed
- Branch mode: branch-comparison
- Startup: 9.802s
- Startup raw: 9802 ms
- Load ready delay after health: 8254 ms
- Startup to load-ready: 18056 ms
- Health endpoint: http://localhost:8080/api/gateway/status
- Load target: GET http://localhost:8080/api/gateway/orders
- Scenario metadata: [scenario.json](scenario.json)
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 6803.49 req/s (p50=3.37ms, p95=5.68ms, p99=6.56ms, errors=na)
- Memory snapshot: analytics-service:362.5MiB, billing-service:384MiB, catalog-service:275.1MiB, gateway-service:550MiB, notification-service:411.8MiB, orders-service:580.8MiB, postgres:158.6MiB, rabbitmq:177MiB, redis:22.53MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
- DB query count: not collected by the current harness
