# Benchmark results for java11

- Startup: 10.522s
- Startup raw: 10522 ms
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 6879.04 req/s (p50=3.29ms, p95=6.33ms, p99=7.49ms, errors=na)
- Memory snapshot: analytics-service:414.4MiB, billing-service:471.5MiB, catalog-service:265.3MiB, gateway-service:817.5MiB, notification-service:462MiB, orders-service:974.5MiB, postgres:88.09MiB, rabbitmq:138.3MiB, redis:3.914MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
