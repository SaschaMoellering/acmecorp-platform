# Benchmark results for java17

- Startup: Waiting for health endpoint (http://localhost:8080/api/gateway/status)...
Waiting for orders endpoint to answer once (http://localhost:8080/api/gateway/orders)...
24s
- Load: 461.93 req/s (p50=9.53ms, p95=24.45ms, p99=32.95ms, errors=11263)
- Memory snapshot: catalog-service:252.6MiB, gateway-service:307.1MiB, orders-service:431.7MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
