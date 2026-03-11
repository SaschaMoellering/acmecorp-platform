# Benchmark results for java21

- Startup: 10.469s
- Startup raw: 10469 ms
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 703.0 req/s (p50=5.08ms, p95=11.25ms, p99=14.00ms, errors=na)
- Memory snapshot: analytics-service:343MiB, billing-service:386.2MiB, catalog-service:252.5MiB, gateway-service:426.5MiB, notification-service:378MiB, orders-service:434.8MiB, postgres:87.35MiB, rabbitmq:137.7MiB, redis:3.902MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
