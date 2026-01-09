# Benchmark results for java21

- Startup: Waiting for health endpoint (http://localhost:8080/api/gateway/status)...
Waiting for orders endpoint to answer once (http://localhost:8080/api/gateway/orders)...
21s
- Load: 455.12 req/s (p50=9.54ms, p95=25.06ms, p99=34.55ms, errors=11536)
- Memory snapshot: catalog-service:262.5MiB, gateway-service:315.1MiB, orders-service:404.7MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
