# Benchmark results for java11

- Startup: Waiting for health endpoint (http://localhost:8080/api/gateway/status)...
Waiting for orders endpoint to answer once (http://localhost:8080/api/gateway/orders)...
16s
- Load: 470.48 req/s (p50=9.66ms, p95=24.34ms, p99=32.91ms, errors=10734)
- Memory snapshot: catalog-service:215.8MiB, gateway-service:499.5MiB, orders-service:512.7MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
