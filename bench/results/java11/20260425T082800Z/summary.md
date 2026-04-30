# Benchmark results for java11

- Startup: 10.526s
- Startup raw: 10526 ms
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 7335.72 req/s (p50=3.11ms, p95=5.54ms, p99=6.49ms, errors=na)
- Memory snapshot: analytics-service:408.4MiB, billing-service:446.2MiB, catalog-service:272.7MiB, gateway-service:662.7MiB, notification-service:424.8MiB, orders-service:848MiB, postgres:94.58MiB, rabbitmq:142.6MiB, redis:3.656MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
