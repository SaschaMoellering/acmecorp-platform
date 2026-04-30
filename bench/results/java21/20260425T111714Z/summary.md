# Benchmark results for java21

- Scenario: mixed
- Branch mode: branch-comparison
- Startup: 10.099s
- Startup raw: 10099 ms
- Load ready delay after health: 8977 ms
- Startup to load-ready: 19076 ms
- Health endpoint: http://localhost:8080/api/gateway/status
- Load target: GET http://localhost:8080/api/gateway/orders
- Scenario metadata: [scenario.json](scenario.json)
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 6654.81 req/s (p50=3.46ms, p95=5.71ms, p99=6.57ms, errors=na)
- Memory snapshot: analytics-service:341.9MiB, billing-service:408.2MiB, catalog-service:258.5MiB, gateway-service:557.8MiB, notification-service:433.4MiB, orders-service:529.2MiB, postgres:94.2MiB, rabbitmq:134.7MiB, redis:3.859MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
- DB query count: not collected by the current harness
