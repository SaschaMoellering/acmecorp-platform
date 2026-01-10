# Benchmark results for java11

- Startup: Waiting for health endpoint (http://localhost:8080/api/gateway/status)...
Waiting for orders endpoint to answer once (http://localhost:8080/api/gateway/orders)...
15s
- Load: 7792.67 req/s (p50=2.96ms, p95=4.79ms, p99=5.46ms, errors=na)
- Memory snapshot: catalog-service:217.1MiB, gateway-service:469MiB, orders-service:478.4MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
