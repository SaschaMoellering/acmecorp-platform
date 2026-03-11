# Benchmark results for java21

- Startup: 10.015s
- Startup raw: 10015 ms
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 6208.6 req/s (p50=3.65ms, p95=6.78ms, p99=8.02ms, errors=na)
- Memory snapshot: analytics-service:367MiB, billing-service:386MiB, catalog-service:262.5MiB, gateway-service:542.9MiB, notification-service:405.7MiB, orders-service:495.4MiB, postgres:86.98MiB, rabbitmq:139.9MiB, redis:3.656MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
