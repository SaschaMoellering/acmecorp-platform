# Benchmark results for java17

- Startup: 11.281s
- Startup raw: 11281 ms
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 727.24 req/s (p50=4.90ms, p95=10.97ms, p99=13.34ms, errors=na)
- Memory snapshot: analytics-service:389.5MiB, billing-service:486.4MiB, catalog-service:259.7MiB, gateway-service:448.4MiB, notification-service:498.7MiB, orders-service:444.2MiB, postgres:85.47MiB, rabbitmq:183.7MiB, redis:3.883MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
