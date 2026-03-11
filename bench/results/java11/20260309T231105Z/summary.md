# Benchmark results for java11

- Startup: 10.774s
- Startup raw: 10774 ms
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 6883.6 req/s (p50=3.29ms, p95=6.31ms, p99=7.47ms, errors=na)
- Memory snapshot: analytics-service:414.9MiB, billing-service:467.4MiB, catalog-service:271.4MiB, gateway-service:913.9MiB, notification-service:464.8MiB, orders-service:913.7MiB, postgres:87.45MiB, rabbitmq:137.5MiB, redis:3.652MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
