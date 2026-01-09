# Benchmark results for java11

- Startup: Waiting for health endpoint (http://localhost:8080/api/gateway/status)...
Waiting for orders endpoint to answer once (http://localhost:8080/api/gateway/orders)...
16s
- Load: 467.05 req/s (p50=9.74ms, p95=25.10ms, p99=34.13ms, errors=10781)
- Memory snapshot: catalog-service:164.9MiB, gateway-service:442.3MiB, orders-service:528.4MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
