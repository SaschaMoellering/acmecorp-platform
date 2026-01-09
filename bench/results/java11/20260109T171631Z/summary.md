# Benchmark results for java11

- Startup: Waiting for health endpoint (http://localhost:8080/api/gateway/status)...
Waiting for orders endpoint to answer once (http://localhost:8080/api/gateway/orders)...
18s
- Load: 470.5 req/s (p50=9.85ms, p95=25.21ms, p99=34.37ms, errors=10585)
- Memory snapshot: catalog-service:256.2MiB, gateway-service:471.2MiB, orders-service:491.7MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
