# Benchmark results for java11

- Startup: 9.876s
- Startup raw: 9876 ms
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 1009.44 req/s (p50=3.77ms, p95=7.50ms, p99=9.37ms, errors=na)
- Memory snapshot: analytics-service:396.5MiB, billing-service:427MiB, catalog-service:277.6MiB, gateway-service:539.8MiB, notification-service:482.4MiB, orders-service:560.7MiB, postgres:86.1MiB, rabbitmq:141MiB, redis:3.648MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
