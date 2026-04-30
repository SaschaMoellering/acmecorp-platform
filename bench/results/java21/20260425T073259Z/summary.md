# Benchmark results for java21

- Scenario: mixed
- Branch mode: branch-comparison
- Startup: 9.444s
- Startup raw: 9444 ms
- Load ready delay after health: 7314 ms
- Startup to load-ready: 16758 ms
- Health endpoint: http://localhost:8080/api/gateway/status
- Load target: GET http://localhost:8080/api/gateway/orders
- Scenario metadata: [scenario.json](scenario.json)
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 6646.89 req/s (p50=3.45ms, p95=5.86ms, p99=6.80ms, errors=na)
- Memory snapshot: analytics-service:322.1MiB, billing-service:349.4MiB, catalog-service:263MiB, gateway-service:546.4MiB, notification-service:391.8MiB, orders-service:567.6MiB, postgres:93.93MiB, rabbitmq:134.6MiB, redis:3.902MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
- DB query count: not collected by the current harness
