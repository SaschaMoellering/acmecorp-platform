# Benchmark results for java21

- Startup: Waiting for health endpoint (http://localhost:8080/api/gateway/status)...
Waiting for orders endpoint to answer once (http://localhost:8080/api/gateway/orders)...
22s
- Load: 461.71 req/s (p50=9.67ms, p95=25.18ms, p99=34.64ms, errors=11129)
- Memory snapshot: catalog-service:261MiB, gateway-service:332.3MiB, orders-service:463.9MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
