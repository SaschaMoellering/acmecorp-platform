# Benchmark summary: 20260309T223147Z

Startup time: 10.752s
Startup raw: 10752 ms
Health endpoint: http://localhost:8080/api/gateway/status
Orders startup trace: [orders-startup.json](orders-startup.json)

Containers:
[
  {
    "service": "postgres",
    "container": "acmecorp-postgres",
    "id": "3da2347d5cf31da7475c38698e2777a5b878301e3a326c619c41dfd8f5e465fe",
    "mem": "84.81MiB"
  },
  {
    "service": "rabbitmq",
    "container": "acmecorp-rabbitmq",
    "id": "3639aa84a937b58ef6b0365e65e0f1de16c471469e10cdc8c646af1c74746904",
    "mem": "139.3MiB"
  },
  {
    "service": "redis",
    "container": "acmecorp-redis",
    "id": "a6e26be7bb32c1f0076c48b4ace83229b296d87c41e7e91fb6f27066e3757ced",
    "mem": "3.898MiB"
  },
  {
    "service": "analytics-service",
    "container": "local-analytics-service-1",
    "id": "171604a75af32032385f89d18822ba7eb9e9eeb1741b6fbeb2935eca71cef689",
    "mem": "395.3MiB"
  },
  {
    "service": "billing-service",
    "container": "local-billing-service-1",
    "id": "2ae2ee7f54050e7e8c8967fb6ab8ae2f43e5a6b1f5eb6551d7aa3c2412c0f2db",
    "mem": "396.4MiB"
  },
  {
    "service": "catalog-service",
    "container": "local-catalog-service-1",
    "id": "313a9541bcf02e78e5db21729b9dbe53fe0e349ba9e2afab5b09f6359681128a",
    "mem": "250.1MiB"
  },
  {
    "service": "gateway-service",
    "container": "local-gateway-service-1",
    "id": "eb1e183a24c3de241e131852f76ac27c403c1bab0f67e2b88ac1b14464233844",
    "mem": "266.7MiB"
  },
  {
    "service": "notification-service",
    "container": "local-notification-service-1",
    "id": "001d71a0a0917975f83cdfed9f0266a54e8c5f05acad8a251531ec86073a42c0",
    "mem": "407.3MiB"
  },
  {
    "service": "orders-service",
    "container": "local-orders-service-1",
    "id": "2fdd6e626dfa605106da5bf804f5c3a5628b1d0b6652b083671070b611517739",
    "mem": "428MiB"
  }
]
