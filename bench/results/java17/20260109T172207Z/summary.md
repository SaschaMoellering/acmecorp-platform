# Benchmark results for java17

- Startup: Waiting for health endpoint (http://localhost:8080/api/gateway/status)...
Waiting for orders endpoint to answer once (http://localhost:8080/api/gateway/orders)...
22s
- Load: 460.5 req/s (p50=9.44ms, p95=24.93ms, p99=34.83ms, errors=10950)
- Memory snapshot: catalog-service:195.7MiB, gateway-service:297.9MiB, orders-service:358.3MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
