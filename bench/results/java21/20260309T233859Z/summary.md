# Benchmark results for java21

- Startup: 10.070s
- Startup raw: 10070 ms
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 6200.98 req/s (p50=3.65ms, p95=6.81ms, p99=8.06ms, errors=na)
- Memory snapshot: analytics-service:404.3MiB, billing-service:416.3MiB, catalog-service:259.2MiB, gateway-service:590.2MiB, notification-service:388.7MiB, orders-service:554.1MiB, postgres:87.16MiB, rabbitmq:135.7MiB, redis:3.895MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
