# Benchmark results for java25

- Startup: 12.074s
- Startup raw: 12074 ms
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: 775.04 req/s (p50=4.84ms, p95=9.24ms, p99=11.21ms, errors=na)
- Memory snapshot: analytics-service:368.1MiB, billing-service:365.2MiB, catalog-service:256.5MiB, gateway-service:320MiB, notification-service:387.4MiB, orders-service:611.1MiB, postgres:86.11MiB, rabbitmq:135MiB, redis:3.855MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
