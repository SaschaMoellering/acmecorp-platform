# Benchmark results for java17

- Startup: 12.259s
- Startup raw: 12259 ms
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 6507.02 req/s (p50=3.47ms, p95=6.73ms, p99=8.00ms, errors=na)
- Memory snapshot: analytics-service:385.9MiB, billing-service:453.9MiB, catalog-service:263.9MiB, gateway-service:622.1MiB, notification-service:452.7MiB, orders-service:656.4MiB, postgres:86.73MiB, rabbitmq:140.8MiB, redis:4.242MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
