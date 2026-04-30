# Benchmark results for java21

- Scenario: mixed
- Branch mode: branch-comparison
- Startup: 12.320s
- Startup raw: 12320 ms
- Load ready delay after health: 9949 ms
- Startup to load-ready: 22269 ms
- Health endpoint: http://localhost:8080/api/gateway/status
- Load target: GET http://localhost:8080/api/gateway/orders
- Scenario metadata: [scenario.json](scenario.json)
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 6113.73 req/s (p50=3.74ms, p95=6.44ms, p99=7.48ms, errors=na)
- Memory snapshot: analytics-service:380.7MiB, billing-service:389.1MiB, catalog-service:282MiB, gateway-service:553.9MiB, notification-service:409.8MiB, orders-service:547.1MiB, postgres:93.64MiB, rabbitmq:142.4MiB, redis:3.895MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
- DB query count: not collected by the current harness
