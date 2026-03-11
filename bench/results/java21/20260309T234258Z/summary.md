# Benchmark results for java21

- Startup: 8.779s
- Startup raw: 8779 ms
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 6241.49 req/s (p50=3.63ms, p95=6.75ms, p99=7.99ms, errors=na)
- Memory snapshot: analytics-service:379.1MiB, billing-service:383.9MiB, catalog-service:245.2MiB, gateway-service:650.3MiB, notification-service:413.6MiB, orders-service:538.3MiB, postgres:87.67MiB, rabbitmq:187.2MiB, redis:3.898MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
