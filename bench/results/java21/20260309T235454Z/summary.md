# Benchmark results for java21

- Startup: 9.387s
- Startup raw: 9387 ms
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 6213.48 req/s (p50=3.65ms, p95=6.79ms, p99=8.05ms, errors=na)
- Memory snapshot: analytics-service:356.7MiB, billing-service:382.3MiB, catalog-service:272.2MiB, gateway-service:543.5MiB, notification-service:425.2MiB, orders-service:729.5MiB, postgres:87.27MiB, rabbitmq:166.8MiB, redis:3.66MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
