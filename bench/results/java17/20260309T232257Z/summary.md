# Benchmark results for java17

- Startup: 11.505s
- Startup raw: 11505 ms
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 6517.44 req/s (p50=3.46ms, p95=6.71ms, p99=7.96ms, errors=na)
- Memory snapshot: analytics-service:431.8MiB, billing-service:401.9MiB, catalog-service:247MiB, gateway-service:538.6MiB, notification-service:390.1MiB, orders-service:553.5MiB, postgres:86.23MiB, rabbitmq:138.8MiB, redis:4.578MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
