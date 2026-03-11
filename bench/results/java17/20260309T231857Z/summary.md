# Benchmark results for java17

- Startup: 12.271s
- Startup raw: 12271 ms
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 6476.15 req/s (p50=3.49ms, p95=6.75ms, p99=8.02ms, errors=na)
- Memory snapshot: analytics-service:433.7MiB, billing-service:414MiB, catalog-service:260.1MiB, gateway-service:524.7MiB, notification-service:445.1MiB, orders-service:528.3MiB, postgres:86.16MiB, rabbitmq:138.3MiB, redis:4.496MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
