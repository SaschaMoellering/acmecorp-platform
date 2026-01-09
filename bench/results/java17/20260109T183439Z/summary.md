# Benchmark results for java17

- Startup: Waiting for health endpoint (http://localhost:8080/api/gateway/status)...
Waiting for orders endpoint to answer once (http://localhost:8080/api/gateway/orders)...
24s
- Load: 464.56 req/s (p50=9.70ms, p95=24.46ms, p99=33.70ms, errors=11082)
- Memory snapshot: catalog-service:228MiB, gateway-service:314.3MiB, orders-service:404.4MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
