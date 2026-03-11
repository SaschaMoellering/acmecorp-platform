# Benchmark results for java11

- Startup: 10.835s
- Startup raw: 10835 ms
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 6871.57 req/s (p50=3.29ms, p95=6.35ms, p99=7.53ms, errors=na)
- Memory snapshot: analytics-service:479.9MiB, billing-service:466.8MiB, catalog-service:273MiB, gateway-service:725.3MiB, notification-service:444MiB, orders-service:895.1MiB, postgres:87.22MiB, rabbitmq:138.1MiB, redis:3.898MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
