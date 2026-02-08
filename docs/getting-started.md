# AcmeCorp Platform – Getting Started

This guide shows how to run the AcmeCorp platform locally with Docker Compose and how to deploy it to Kubernetes (and later to Amazon EKS using Helm).

The guide is written as a **hands-on runbook**: every section can be executed independently and is suitable for workshops, demos, and video recordings.

---

## 1. Prerequisites

### Required

* **Docker Engine + Docker Compose v2** (Docker plugin)
* **Java 21** (for local builds and tests)
* **Maven 3.9+**
* **Node.js 18+** (only required if you build or run the React UI)
* **kubectl** plus a local Kubernetes cluster (kind, k3d, or Minikube)
* **Helm 3**

### Optional

* **GNU Make** (for convenience targets like `make up`, `make smoke-local`)
* **kube-prometheus-stack** (for observability)

---

## 2. Run Everything Locally with Docker Compose

From the repository root:

```bash
cd infra/local
docker compose up --build
```

This starts the full local stack:

### Infrastructure

* PostgreSQL (`localhost:5432`)
* Redis (`localhost:6379`)
* RabbitMQ (`localhost:5672`, Management UI: `http://localhost:15672`)

### Backend Services

* orders-service (`http://localhost:8081`)
* billing-service (`http://localhost:8082`)
* notification-service (`http://localhost:8083`)
* analytics-service (`http://localhost:8084`)
* catalog-service (Quarkus, `http://localhost:8085`)
* gateway-service (`http://localhost:8080`)

> **Note**
> In real deployments, **only the gateway-service is accessed externally**.
> Individual services are exposed locally **for debugging and development only**.

### Example API Calls (via Gateway)

```bash
curl http://localhost:8080/api/gateway/orders
curl http://localhost:8080/api/gateway/catalog
curl http://localhost:8080/api/gateway/analytics/counters
curl http://localhost:8080/api/gateway/system/status
```

### Direct Service Calls (local debugging only)

```bash
curl "http://localhost:8083/api/notification/send?recipient=test@example.com&message=hello"
curl "http://localhost:8084/api/analytics/track?event=page-view"
```

### Create Sample Data

```bash
# create a catalog product
curl -X POST http://localhost:8080/api/gateway/catalog \
  -H "Content-Type: application/json" \
  -d '{"sku":"SKU-CLI-01","name":"CLI Created","description":"from docs","price":42,"currency":"USD","category":"DOCS","active":true}'

# create and confirm an order
curl -X POST http://localhost:8080/api/gateway/orders \
  -H "Content-Type: application/json" \
  -d '{"customerEmail":"docs@example.com","items":[{"productId":"11111111-1111-1111-1111-111111111111","quantity":1}]}'

curl -X POST http://localhost:8080/api/gateway/orders/1/confirm
```

---

## 3. Integration Tests (Local Stack)

Integration tests run against a **real, running stack**.

### Steps

```bash
# start the stack
cd infra/local
docker compose up -d

# run integration tests
cd ../../integration-tests
mvn test

# optional cleanup
cd ../infra/local
docker compose down
```

* Default base URL: `http://localhost:8080`
* Override with:

```bash
ACMECORP_BASE_URL=http://localhost:8080 mvn test
```

> **Note**
> Integration tests assume a **clean database state**.
> If tests fail unexpectedly, ensure no leftover containers are running.

---

## 4. Kubernetes Deployment (Base Manifests)

Ensure your cluster context is configured:

```bash
kubectl config current-context
```

Apply the base manifests:

```bash
kubectl apply -k infra/k8s/base
```

This creates:

* Namespace `acmecorp`
* Deployments and Services for all backend services
* `gateway-service` (ClusterIP)
* Ingress `gateway-ingress` routing external traffic to the gateway

Check resources:

```bash
kubectl get pods -n acmecorp
kubectl get svc -n acmecorp
kubectl get ingress -n acmecorp
```

### Local Ingress Access (example)

```text
127.0.0.1 acmecorp.local
```

```bash
curl http://acmecorp.local/api/gateway/orders
```

---

## 5. Frontend Configuration

The React SPA reads the API base URL from `VITE_API_BASE_URL`.

* Default: `http://localhost:8080`
* Kubernetes (Ingress):

```bash
VITE_API_BASE_URL=http://acmecorp.local npm run dev
```

For production, the API base URL should be injected **at build time** rather than runtime.

---

## 6. Helm Deployment

Install the full platform as a single Helm release:

```bash
helm install acmecorp charts/acmecorp-platform -n acmecorp --create-namespace
```

Override defaults using a custom values file:

```bash
helm upgrade --install acmecorp charts/acmecorp-platform \
  -n acmecorp -f values-local.yaml
```

* Secrets (DB, RabbitMQ credentials) are stored in Kubernetes Secrets
* Non-sensitive configuration is stored in ConfigMaps and `values.yaml`

---

## 7. Observability (Prometheus & Grafana)

Install the Prometheus stack:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace
```

Apply AcmeCorp ServiceMonitors:

```bash
kubectl apply -f infra/observability/k8s/
```

Grafana dashboards:

* JVM memory and CPU (Spring Boot + Quarkus)
* HTTP latency and request rates
* Gateway traffic overview

Import:

* `infra/observability/grafana/acmecorp-jvm-http-overview.json`

> **Note (Quarkus)**
> Ensure Prometheus export is enabled:
> `quarkus.micrometer.export.prometheus.enabled=true`

---

## 7a. Local Observability (Prometheus, Grafana, Alertmanager)

Bring up the local observability stack alongside the platform:

```bash
docker compose -f infra/local/docker-compose.yml -f infra/local/docker-compose.observability.yml up --build
```

UIs:

- Prometheus: http://localhost:9090
- Alertmanager: http://localhost:9093
- Grafana: http://localhost:3000 (admin/admin)

Demo alert trigger (ServiceDown):

```bash
docker compose stop billing-service
```

Quarkus metrics path for catalog-service is `/q/metrics`.

Quick verification (from host):

```bash
curl -s http://localhost:8085/q/metrics | head -n 5
```

---

## 8. Seed Data Tool

* API: `POST /api/gateway/seed`
* UI: **Tools → Seed Data → Load Demo Data**

The seed tool:

* Creates deterministic catalog items and orders
* Uses fixed UUID patterns for predictable testing
* Is ideal for demos, dashboards, and workshops

---

## 9. Tests and Smoke Checks

### Backend

```bash
make test-backend
```

### Frontend

```bash
cd webapp
npm install
npm test
```

### Frontend E2E (Playwright)

```bash
npm run test:e2e
npm run test:e2e -- --grep "manage catalog"
```

### Smoke Tests

```bash
BASE_URL=http://localhost:8080 ./scripts/smoke-local.sh
```

---

## 10. Next Steps

* Integrate additional UI features
* Extend analytics event coverage
* Add alerting rules to Grafana / Prometheus
* Use this repository as the backbone for video episodes and live demos

---

# Appendix A – Troubleshooting

## Docker / Compose

**Problem:** `docker-compose: command not found`
**Fix:** Use Docker Compose v2:

```bash
docker compose version
```

---

## Ports Already in Use

**Problem:** Containers fail to start due to port conflicts
**Fix:** Stop existing containers:

```bash
docker ps
docker stop <container>
```

---

## Gateway Returns 502 / 503

**Cause:** Downstream service not ready
**Fix:**

```bash
docker compose ps
docker compose logs gateway-service
```

Wait until all services report healthy.

---

## Integration Tests Failing

**Cause:** Dirty database state or leftover containers
**Fix:**

```bash
docker compose down -v
docker compose up -d
```

---

## Kubernetes: No External Access

**Cause:** Ingress controller not installed
**Fix:** Install nginx, Traefik, or your preferred ingress controller.

---

## Grafana Shows No Metrics

**Checklist:**

* Are ServiceMonitors applied?
* Is Prometheus scraping the `actuator/prometheus` endpoints?
* Are the pods running in the expected namespace?

---

## Quarkus Service Missing Metrics

Ensure:

```properties
quarkus.micrometer.export.prometheus.enabled=true
```

---

## RabbitMQ UI Not Reachable

```bash
http://localhost:15672
# default credentials: guest / guest
```

---

## Reset Everything (Local)

```bash
docker compose down -v
docker system prune -f
```
