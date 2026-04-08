# Benchmark results for java21

- Scenario: orders-startup
- Branch mode: branch-comparison
- Startup: 17.488s
- Startup raw: 17488 ms
- Load ready delay after health: na ms
- Startup to load-ready: na ms
- Health endpoint: http://localhost:8081/api/orders/status
- Load target: GET http://localhost:8080/api/gateway/orders
- Scenario metadata: [scenario.json](scenario.json)
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: na req/s (p50=na, p95=na, p99=na, errors=na)
- Memory snapshot: analytics-service:358.1MiB, billing-service:377.4MiB, catalog-service:283.7MiB, gateway-service:236.3MiB, notification-service:375.5MiB, orders-service:406.9MiB, postgres:94.99MiB, rabbitmq:145.5MiB, redis:8.41MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
- DB query count: not collected by the current harness
