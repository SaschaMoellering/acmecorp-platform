# Benchmark results for main

- Startup: Waiting for health endpoint (http://localhost:8080/api/gateway/status)...
Waiting for orders endpoint to answer once (http://localhost:8080/api/gateway/orders)...
45s
- Load: 3406.28 req/s (p50=1.38ms, p95=128.61ms, p99=181.10ms, errors=0)
- Memory snapshot: catalog-service:171.2MiB, gateway-service:235.1MiB, orders-service:312.6MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
