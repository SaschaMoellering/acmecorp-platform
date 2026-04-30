# Benchmark results for java25

- Scenario: mixed
- Branch mode: branch-comparison
- Startup: 11.394s
- Startup raw: 11394 ms
- Load ready delay after health: 5521 ms
- Startup to load-ready: 16915 ms
- Health endpoint: http://localhost:8080/api/gateway/status
- Load target: GET http://localhost:8080/api/gateway/orders
- Scenario metadata: [scenario.json](scenario.json)
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 5477.49 req/s (p50=4.19ms, p95=7.17ms, p99=8.34ms, errors=na)
- Memory snapshot: analytics-service:378.5MiB, billing-service:392.1MiB, catalog-service:295.3MiB, gateway-service:657.5MiB, notification-service:385.4MiB, orders-service:640.6MiB, postgres:93.93MiB, rabbitmq:138.6MiB, redis:3.914MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
- DB query count: not collected by the current harness
