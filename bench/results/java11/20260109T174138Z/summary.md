# Benchmark results for java11

- Startup: Waiting for health endpoint (http://localhost:8080/api/gateway/status)...
Waiting for orders endpoint to answer once (http://localhost:8080/api/gateway/orders)...
18s
- Load: 470.47 req/s (p50=9.78ms, p95=24.60ms, p99=33.40ms, errors=10719)
- Memory snapshot: catalog-service:207.4MiB, gateway-service:444.9MiB, orders-service:443.1MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
