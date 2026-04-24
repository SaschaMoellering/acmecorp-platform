# Benchmark results for java25

- Scenario: mixed
- Branch mode: branch-comparison
- Startup: 12.019s
- Startup raw: 12019 ms
- Load ready delay after health: 5266 ms
- Startup to load-ready: 17285 ms
- Health endpoint: http://localhost:8080/api/gateway/status
- Load target: GET http://localhost:8080/api/gateway/orders
- Scenario metadata: [scenario.json](scenario.json)
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 5467.65 req/s (p50=4.18ms, p95=7.40ms, p99=8.73ms, errors=na)
- Memory snapshot: analytics-service:357.6MiB, billing-service:361.2MiB, catalog-service:260.7MiB, gateway-service:519MiB, notification-service:401.4MiB, orders-service:674.4MiB, postgres:93.96MiB, rabbitmq:141.8MiB, redis:3.898MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
- DB query count: not collected by the current harness
