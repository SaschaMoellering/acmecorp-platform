# Benchmark results for java11

- Startup: Waiting for health endpoint (http://localhost:8080/api/gateway/status)...
Waiting for orders endpoint to answer once (http://localhost:8080/api/gateway/orders)...
17s
- Load: 469.01 req/s (p50=9.70ms, p95=25.17ms, p99=34.45ms, errors=10705)
- Memory snapshot: catalog-service:260MiB, gateway-service:506.6MiB, orders-service:530.8MiB
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
