# AcmeCorp Platform Overview Dashboard Validation

Target dashboard: `infra/local/observability/grafana/dashboards/acmecorp-platform-overview.json`

Note: Grafana dashboards in this repo reference the Prometheus datasource by UID `prometheus`. Ensure provisioning sets the datasource UID explicitly.
Note: The Application variable uses regex matchers, so its All-value must be `.*` (Grafana’s default $__all can break regex expressions).
Note: The gateway 5xx panel uses `or vector(0)` so it renders 0% when no 5xx series exist.

## What I checked
- Dashboard JSON location and contents.
- Prometheus scrape configs and labels (local Prometheus + k8s ServiceMonitors).
- Micrometer/Prometheus registry dependencies for services.
- PromQL queries for metrics/labels and common failure modes.

## Evidence (repo files)
- Local Prometheus scrape labels include `application`: `infra/local/observability/prometheus/prometheus.yml`
- Dashboard JSON present: `infra/local/observability/grafana/dashboards/acmecorp-platform-overview.json`
- Micrometer registry enabled in services: `services/spring-boot/*/pom.xml`, `services/quarkus/catalog-service/pom.xml`
- k8s ServiceMonitors (no `application` label by default): `infra/observability/k8s/*-servicemonitor.yaml`

## What was wrong / risky
1) **Services Up panel counted targets, not applications**
   - `sum(up{application=~"$application"})` counts targets. The requirement is “number of applications with at least one UP target.”

2) **Gateway 5xx ratio and latency fallback could divide by zero**
   - When there is no traffic, `sum(rate(...))` can be 0, which yields `NaN`.

3) **$application variable in k8s would be empty**
   - Local Prometheus sets `application` labels, but k8s ServiceMonitors do not, so `label_values(up, application)` would be empty in cluster deployments unless relabeled.

## Changes made (before/after)

### 1) Services Up (count applications with at least one UP)
**Before**
```
sum(up{application=~"$application"})
```
**After**
```
sum(max by (application) (up{application=~"$application"}))
```

### 2) Gateway 5xx ratio (safe denominator)
**Before**
```
100 * (sum(rate(http_server_requests_seconds_count{application="gateway-service",status=~"5.."}[5m])) /
  sum(rate(http_server_requests_seconds_count{application="gateway-service"}[5m])))
```
**After**
```
100 * (sum(rate(http_server_requests_seconds_count{application="gateway-service",status=~"5.."}[5m])) /
  clamp_min(sum(rate(http_server_requests_seconds_count{application="gateway-service"}[5m])), 1e-9))
```

### 3) Gateway latency avg fallback (safe denominator)
**Before**
```
sum(rate(http_server_requests_seconds_sum{application="gateway-service"}[5m])) /
  sum(rate(http_server_requests_seconds_count{application="gateway-service"}[5m]))
```
**After**
```
sum(rate(http_server_requests_seconds_sum{application="gateway-service"}[5m])) /
  clamp_min(sum(rate(http_server_requests_seconds_count{application="gateway-service"}[5m])), 1e-9)
```

### 4) k8s ServiceMonitor relabeling (ensure `application` label)
Added relabeling so `label_values(up, application)` works in k8s:
```
relabelings:
  - sourceLabels: [__meta_kubernetes_service_label_app]
    targetLabel: application
    action: replace
```
Files updated:
- `infra/observability/k8s/gateway-service-servicemonitor.yaml`
- `infra/observability/k8s/orders-service-servicemonitor.yaml`
- `infra/observability/k8s/billing-service-servicemonitor.yaml`
- `infra/observability/k8s/notification-service-servicemonitor.yaml`
- `infra/observability/k8s/analytics-service-servicemonitor.yaml`

## How to verify in Grafana Explore
Run these PromQL queries directly:
- Variable sanity:
  - `label_values(up, application)`
- Services Up:
  - `sum(max by (application) (up{application=~"$application"}))`
- Gateway RPS:
  - `sum(rate(http_server_requests_seconds_count{application="gateway-service"}[5m]))`
- Gateway 5xx ratio components:
  - `sum(rate(http_server_requests_seconds_count{application="gateway-service",status=~"5.."}[5m]))`
  - `sum(rate(http_server_requests_seconds_count{application="gateway-service"}[5m]))`
- Gateway latency:
  - `histogram_quantile(0.95, sum by (le) (rate(http_server_requests_seconds_bucket{application="gateway-service"}[5m])))`
  - `sum(rate(http_server_requests_seconds_sum{application="gateway-service"}[5m])) / clamp_min(sum(rate(http_server_requests_seconds_count{application="gateway-service"}[5m])), 1e-9)`
- JVM metrics:
  - `jvm_memory_used_bytes{application=~"$application",area="heap"}`
  - `jvm_threads_live_threads{application=~"$application"}`

## TODOs / Assumptions
- **Assumption:** Spring Boot Micrometer exposes `http_server_requests_seconds_*` with label `status` (standard default). If your environment uses `status_code` or `outcome`, update the 5xx filter accordingly.
  - Verify in Explore: `label_values(http_server_requests_seconds_count{application="gateway-service"}, status)`
  - If empty, try: `label_values(http_server_requests_seconds_count{application="gateway-service"}, status_code)` or `... outcome`.

## Commands used (for reproducibility)
- Find dashboard JSON:
  - `rg -n "acmecorp-platform-overview|AcmeCorp Platform Overview" -S .`
- Find Prometheus config / ServiceMonitors:
  - `rg -n "prometheus" infra -S`
- Find Micrometer/Prometheus registry usage:
  - `rg -n "micrometer|prometheus" services -S`
