# AcmeCorp Platform Overview Dashboard Validation

Target dashboard: `infra/local/observability/grafana/dashboards/acmecorp-platform-overview.json`

Note: Grafana dashboards in this repo reference the Prometheus datasource by UID `prometheus`. Ensure provisioning sets the datasource UID explicitly.
Note: The Application variable uses regex matchers, so its All-value must be `.*` (Grafana’s default $__all can break regex expressions).
Note: The gateway 5xx panel uses `or vector(0)` so it renders 0% when no 5xx series exist.
Note: Dashboards are provisioned from `infra/local/observability/grafana/dashboards/`.

## Templating Contract
If a Grafana variable is Multi-value or Include All, use a regex matcher in PromQL: `label=~"$var"`.
Do not use `label="$var"` because All=`.*` and multi-select will produce no data.

Example (correct):
`jvm_memory_used_bytes{application=~"$application"}`

Example (incorrect):
`jvm_memory_used_bytes{application="$application"}`

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
  - `sum by (application) (jvm_memory_used_bytes{application=~"$application",area="heap"})`
  - `max by (application) (jvm_threads_live_threads{application=~"$application"})`

## Why JVM aggregation is required
Micrometer JVM metrics include labels like `area`, `id`, and `state`. Panels that plot raw series per application will produce multiple series (one per label value), which can make overview panels show “No data” when they expect a single series per application. Aggregating by `application` (or `application, area/state`) produces stable, readable panels.

## JVM metrics verification (local Compose)
Use the repo script to query Prometheus from inside the Compose network:

```bash
scripts/observability/verify-metrics.sh
```

Expected outcomes:
- `count(jvm_.*)` should be greater than 0.
- `count(jvm_.*, application="gateway-service")` should be greater than 0.
- Example series should show an `application` label on JVM and process metrics.

Prometheus API checks (no UI):
- `http://prometheus:9090/api/v1/query?query=count({__name__=~"jvm_.*"})`
- `http://prometheus:9090/api/v1/query?query=count({__name__=~"jvm_.*",application="gateway-service"})`
- `http://prometheus:9090/api/v1/series?match[]={__name__=~"jvm_.*"}`
- `http://prometheus:9090/api/v1/query?query=count(http_server_requests_seconds_count{application="gateway-service"})`

## Gateway traffic breakdown checks
Use these queries to validate the breakdown dashboard panels:
- RPS by method: `sum by (method) (rate(http_server_requests_seconds_count{application="gateway-service"}[1m]))`
- RPS by uri: `sum by (uri) (rate(http_server_requests_seconds_count{application="gateway-service"}[1m]))`
- RPS by route (if available): `sum by (route) (rate(http_server_requests_seconds_count{application="gateway-service"}[1m]))`
- Error rate by method + uri: `sum by (method, uri, status) (rate(http_server_requests_seconds_count{application="gateway-service",status=~"4..|5.."}[5m]))`
- Error rate by method + route: `sum by (method, route, status) (rate(http_server_requests_seconds_count{application="gateway-service",status=~"4..|5.."}[5m]))`
- p95 latency by uri: `histogram_quantile(0.95, sum by (le, uri) (rate(http_server_requests_seconds_bucket{application="gateway-service"}[5m])))`
- avg latency by uri (fallback): `sum by (uri) (rate(http_server_requests_seconds_sum{application="gateway-service"}[5m])) / clamp_min(sum by (uri) (rate(http_server_requests_seconds_count{application="gateway-service"}[5m])), 1e-9)`

## JVM panel checks (local Compose)
Run these in Explore to confirm which JVM metrics exist:
- `{__name__=~"jvm_.*", application=~".+"}`
- `sum by (application) (jvm_memory_used_bytes{application=~"$application",area="heap"})`
- `max by (application) (jvm_threads_live_threads{application=~"$application"})`

## JVM GC breakdown checks
Validate GC dashboard panels with:
- Pause buckets present: `sum by (le, application) (rate(jvm_gc_pause_seconds_bucket{application=~"$application"}[5m]))`
- Pause count: `sum by (application) (rate(jvm_gc_pause_seconds_count{application=~"$application"}[5m]))`
- Pause sum: `sum by (application) (rate(jvm_gc_pause_seconds_sum{application=~"$application"}[5m]))`
- Allocation rate (if present): `sum by (application) (rate(jvm_gc_memory_allocated_bytes_total{application=~"$application"}[5m]))`
- Promotion rate (if present): `sum by (application) (rate(jvm_gc_memory_promoted_bytes_total{application=~"$application"}[5m]))`

## JVM thread + memory breakdown checks
Validate thread + memory dashboard panels with:
- Live/daemon/peak: `max by (application) (jvm_threads_live_threads{application=~"$application"})`, `max by (application) (jvm_threads_daemon_threads{application=~"$application"})`, `max by (application) (jvm_threads_peak_threads{application=~"$application"})`
- Thread states: `sum by (application, state) (jvm_threads_states_threads{application=~"$application"})`
- Heap vs non-heap: `sum by (application, area) (jvm_memory_used_bytes{application=~"$application"})`
- Top pools: `topk(10, sum by (application, id) (jvm_memory_used_bytes{application=~"$application"}))`
- Heap committed/max: `sum by (application) (jvm_memory_committed_bytes{application=~"$application",area="heap"})`, `sum by (application) (jvm_memory_max_bytes{application=~"$application",area="heap"})`
- Buffers (if present): `sum by (application) (jvm_buffer_memory_used_bytes{application=~"$application"})`, `sum by (application) (jvm_buffer_total_capacity_bytes{application=~"$application"})`

## Minimal validation checklist
1. Set Application = All; confirm JVM Heap and Threads panels render.
2. Select 2 applications; confirm panels render both.
3. Select 1 application; confirm panels render only that app.

## Quick Explore queries
- `jvm_memory_used_bytes{application=~"$application"}`
- `jvm_threads_live_threads{application=~"$application"}`
- `jvm_gc_pause_seconds_count{application=~"$application"}`

Optional Prometheus API probes (no UI required):
- `curl -s http://localhost:9090/api/v1/label/__name__/values | jq -r '.data[]' | grep '^jvm_'`
- `curl -s "http://localhost:9090/api/v1/series?match[]=http_server_requests_seconds_count{application=\"gateway-service\"}" | jq -r '.data[0]'`

## Gateway traffic breakdown checks
Use these queries to validate the new dashboard panels:
- RPS by method: `sum by (method) (rate(http_server_requests_seconds_count{application="gateway-service"}[1m]))`
- RPS by uri: `sum by (uri) (rate(http_server_requests_seconds_count{application="gateway-service"}[1m]))`
- RPS by route (if available): `sum by (route) (rate(http_server_requests_seconds_count{application="gateway-service"}[1m]))`
- Error rate by method + uri: `sum by (method, uri, status) (rate(http_server_requests_seconds_count{application="gateway-service",status=~"4..|5.."}[5m]))`
- Error rate by method + route: `sum by (method, route, status) (rate(http_server_requests_seconds_count{application="gateway-service",status=~"4..|5.."}[5m]))`
- p95 latency by uri: `histogram_quantile(0.95, sum by (le, uri) (rate(http_server_requests_seconds_bucket{application="gateway-service"}[5m])))`
- avg latency by uri (fallback): `sum by (uri) (rate(http_server_requests_seconds_sum{application="gateway-service"}[5m])) / clamp_min(sum by (uri) (rate(http_server_requests_seconds_count{application="gateway-service"}[5m])), 1e-9)`

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
