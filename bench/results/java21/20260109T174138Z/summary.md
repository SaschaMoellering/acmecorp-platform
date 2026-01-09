# Benchmark results for java21

- Startup: Waiting for health endpoint (http://localhost:8080/api/gateway/status)...
Waiting for orders endpoint to answer once (http://localhost:8080/api/gateway/orders)...
21s
- Load: 462.81 req/s (p50=9.98ms, p95=26.01ms, p99=36.00ms, errors=10597)
- Memory snapshot: catalog-service:263.3MiB, gateway-service:324.2MiB, orders-service:413MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
