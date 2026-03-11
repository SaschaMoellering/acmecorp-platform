# Benchmark results for java17

- Startup: 12.697s
- Startup raw: 12697 ms
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 6498.41 req/s (p50=3.47ms, p95=6.73ms, p99=7.99ms, errors=na)
- Memory snapshot: analytics-service:402.7MiB, billing-service:372.7MiB, catalog-service:254.1MiB, gateway-service:569.7MiB, notification-service:436.4MiB, orders-service:580MiB, postgres:86.24MiB, rabbitmq:136MiB, redis:3.656MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
