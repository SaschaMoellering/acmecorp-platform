# Benchmark results for java17

- Startup: 13.446s
- Startup raw: 13446 ms
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 6446.03 req/s (p50=3.50ms, p95=6.81ms, p99=8.10ms, errors=na)
- Memory snapshot: analytics-service:381.9MiB, billing-service:463MiB, catalog-service:276.2MiB, gateway-service:464.5MiB, notification-service:436MiB, orders-service:532.2MiB, postgres:86.02MiB, rabbitmq:137.5MiB, redis:4.699MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
