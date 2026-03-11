# Benchmark results for java11

- Startup: 10.779s
- Startup raw: 10779 ms
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 6804.15 req/s (p50=3.32ms, p95=6.44ms, p99=7.65ms, errors=na)
- Memory snapshot: analytics-service:395.2MiB, billing-service:478.3MiB, catalog-service:267.7MiB, gateway-service:783MiB, notification-service:471MiB, orders-service:1.415GiB, postgres:88.35MiB, rabbitmq:142.1MiB, redis:3.898MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
