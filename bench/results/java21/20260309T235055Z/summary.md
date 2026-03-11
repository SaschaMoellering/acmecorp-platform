# Benchmark results for java21

- Startup: 10.211s
- Startup raw: 10211 ms
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 6231.46 req/s (p50=3.64ms, p95=6.77ms, p99=8.02ms, errors=na)
- Memory snapshot: analytics-service:405.4MiB, billing-service:405.2MiB, catalog-service:260.4MiB, gateway-service:544.6MiB, notification-service:410.4MiB, orders-service:605.5MiB, postgres:87.04MiB, rabbitmq:175.5MiB, redis:3.656MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
