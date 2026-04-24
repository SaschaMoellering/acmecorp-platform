# Benchmark results for java25

- Scenario: mixed
- Branch mode: branch-comparison
- Startup: 15.833s
- Startup raw: 15833 ms
- Load ready delay after health: 7489 ms
- Startup to load-ready: 23322 ms
- Health endpoint: http://localhost:8080/api/gateway/status
- Load target: GET http://localhost:8080/api/gateway/orders
- Scenario metadata: [scenario.json](scenario.json)
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 2945.34 req/s (p50=7.56ms, p95=16.46ms, p99=20.27ms, errors=na)
- Memory snapshot: analytics-service:378.8MiB, billing-service:381.9MiB, catalog-service:272.8MiB, gateway-service:617.2MiB, notification-service:0B, orders-service:633.1MiB, postgres:80.18MiB, rabbitmq:146.4MiB, redis:3.656MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
- DB query count: not collected by the current harness
