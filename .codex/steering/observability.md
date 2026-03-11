# Observability Standards

All services must expose Prometheus metrics.

Required endpoint:

/actuator/prometheus

Metrics should include:

- JVM metrics
- HTTP request metrics
- database connection metrics

Visualization:

Grafana dashboards are provided in:

/observability/grafana
