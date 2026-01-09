# Benchmark results for java17

- Startup: Waiting for health endpoint (http://localhost:8080/api/gateway/status)...
Waiting for orders endpoint to answer once (http://localhost:8080/api/gateway/orders)...
24s
- Load: 456.53 req/s (p50=9.48ms, p95=25.32ms, p99=34.87ms, errors=11102)
- Memory snapshot: catalog-service:252.4MiB, gateway-service:308.3MiB, orders-service:422.5MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
