# Benchmark results for java11

- Startup: 10.134s
- Startup raw: 10134 ms
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 6768.45 req/s (p50=3.34ms, p95=6.44ms, p99=7.63ms, errors=na)
- Memory snapshot: analytics-service:487.9MiB, billing-service:458.7MiB, catalog-service:285.5MiB, gateway-service:768.7MiB, notification-service:493.2MiB, orders-service:882.8MiB, postgres:87.7MiB, rabbitmq:140.5MiB, redis:3.664MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
