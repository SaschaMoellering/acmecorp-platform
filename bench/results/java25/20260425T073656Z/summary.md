# Benchmark results for java25

- Scenario: mixed
- Branch mode: branch-comparison
- Startup: 11.873s
- Startup raw: 11873 ms
- Load ready delay after health: 5215 ms
- Startup to load-ready: 17088 ms
- Health endpoint: http://localhost:8080/api/gateway/status
- Load target: GET http://localhost:8080/api/gateway/orders
- Scenario metadata: [scenario.json](scenario.json)
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 5555.25 req/s (p50=4.14ms, p95=7.12ms, p99=8.30ms, errors=na)
- Memory snapshot: analytics-service:398.6MiB, billing-service:387.4MiB, catalog-service:262.9MiB, gateway-service:610.4MiB, notification-service:422.9MiB, orders-service:666.3MiB, postgres:93.7MiB, rabbitmq:136.5MiB, redis:3.648MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
- DB query count: not collected by the current harness
