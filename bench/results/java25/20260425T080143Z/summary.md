# Benchmark results for java25

- Scenario: mixed
- Branch mode: branch-comparison
- Startup: 12.779s
- Startup raw: 12779 ms
- Load ready delay after health: 5804 ms
- Startup to load-ready: 18583 ms
- Health endpoint: http://localhost:8080/api/gateway/status
- Load target: GET http://localhost:8080/api/gateway/orders
- Scenario metadata: [scenario.json](scenario.json)
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 4966.0 req/s (p50=4.59ms, p95=8.31ms, p99=9.82ms, errors=na)
- Memory snapshot: analytics-service:382MiB, billing-service:390.4MiB, catalog-service:259.7MiB, gateway-service:547.2MiB, notification-service:368.5MiB, orders-service:479.9MiB, postgres:93.73MiB, rabbitmq:134.7MiB, redis:3.664MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
- DB query count: not collected by the current harness
