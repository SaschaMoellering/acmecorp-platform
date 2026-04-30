# Benchmark results for java21

- Scenario: mixed
- Branch mode: branch-comparison
- Startup: 10.484s
- Startup raw: 10484 ms
- Load ready delay after health: 8894 ms
- Startup to load-ready: 19378 ms
- Health endpoint: http://localhost:8080/api/gateway/status
- Load target: GET http://localhost:8080/api/gateway/orders
- Scenario metadata: [scenario.json](scenario.json)
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 6680.93 req/s (p50=3.44ms, p95=5.72ms, p99=6.59ms, errors=na)
- Memory snapshot: analytics-service:365.7MiB, billing-service:376.7MiB, catalog-service:299.2MiB, gateway-service:543.6MiB, notification-service:427.8MiB, orders-service:536.4MiB, postgres:93.57MiB, rabbitmq:133.6MiB, redis:4.398MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
- DB query count: not collected by the current harness
