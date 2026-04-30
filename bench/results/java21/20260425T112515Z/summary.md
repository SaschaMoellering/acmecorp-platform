# Benchmark results for java21

- Scenario: mixed
- Branch mode: branch-comparison
- Startup: 10.924s
- Startup raw: 10924 ms
- Load ready delay after health: 7586 ms
- Startup to load-ready: 18510 ms
- Health endpoint: http://localhost:8080/api/gateway/status
- Load target: GET http://localhost:8080/api/gateway/orders
- Scenario metadata: [scenario.json](scenario.json)
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 6705.14 req/s (p50=3.43ms, p95=5.71ms, p99=6.60ms, errors=na)
- Memory snapshot: analytics-service:335.2MiB, billing-service:384.6MiB, catalog-service:287MiB, gateway-service:573.3MiB, notification-service:440.4MiB, orders-service:728MiB, postgres:94.39MiB, rabbitmq:145.1MiB, redis:4.152MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
- DB query count: not collected by the current harness
