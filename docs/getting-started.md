# AcmeCorp Platform – Getting Started

This guide shows how to run the AcmeCorp platform locally with Docker Compose,
and how to deploy it to Kubernetes (and later to EKS with Helm).

## 1. Prerequisites

- Docker / Docker Compose
- Java 21 (for local builds)
- Maven 3.9+
- Node.js (if you add or run the React UI)
- kubectl + a local Kubernetes cluster (kind, k3d, or Minikube) for K8s
- Helm 3 for Helm deployment
- (Optional) Prometheus Operator / kube-prometheus-stack

## 2. Run Everything Locally with Docker Compose

From the repo root:

```bash
cd infra/local
docker compose up --build
```

This will start:

- PostgreSQL (`localhost:5432`)
- Redis (`localhost:6379`)
- RabbitMQ (`localhost:5672`, UI on `http://localhost:15672`)
- orders-service (`http://localhost:8081`)
- billing-service (`http://localhost:8082`)
- notification-service (`http://localhost:8083`)
- analytics-service (`http://localhost:8084`)
- catalog-service (Quarkus, `http://localhost:8085`)
- gateway-service (`http://localhost:8080`)

Example calls:

```bash
curl http://localhost:8080/api/gateway/orders
curl http://localhost:8080/api/gateway/catalog
curl http://localhost:8080/api/gateway/analytics/counters
curl http://localhost:8080/api/gateway/system/status

curl http://localhost:8083/api/notification/send?recipient=test@example.com&message=hello
curl http://localhost:8084/api/analytics/track?event=page-view
```

## 3. Kubernetes Deployment (Base Manifests)

Ensure you have a cluster configured in `kubectl`:

```bash
kubectl config current-context
```

Deploy the base manifests:

```bash
kubectl apply -k infra/k8s/base
```

This will create:

- Namespace `acmecorp`
- Deployments + Services for:
  - orders-service
  - billing-service
  - notification-service
  - analytics-service
  - catalog-service
  - gateway-service (type `LoadBalancer`)
- An Ingress `gateway-ingress` routed to `gateway-service`

Check resources:

```bash
kubectl get pods -n acmecorp
kubectl get svc -n acmecorp
kubectl get ingress -n acmecorp
```

If you use nginx ingress and `/etc/hosts` entry like:

```text
127.0.0.1 acmecorp.local
```

You can access the gateway at:

```bash
curl http://acmecorp.local/api/gateway/orders
```

### Frontend (webapp) API base URL & Helm creds

The React SPA reads `VITE_API_BASE_URL` (default `http://localhost:8080`). Set it to the ingress host when running in Kubernetes:

```bash
VITE_API_BASE_URL=http://acmecorp.local npm run dev
```

or bake it into a ConfigMap/ENV when serving the built assets.

Helm chart credentials:
- Postgres/RabbitMQ credentials are provided via Secrets (defaults in `values.yaml`, override with your own).
- Non-sensitive DB settings (DB name, host, ports) are in ConfigMaps/values.
Adjust them with a values override file when installing/upgrading Helm.

## 4. Helm Deployment

The Helm chart bundles all services under one release.

Install into `acmecorp` namespace:

```bash
helm install acmecorp charts/acmecorp-platform -n acmecorp --create-namespace
```

To override images or disable some services, create a `values-local.yaml` and use:

```bash
helm upgrade --install acmecorp charts/acmecorp-platform -n acmecorp -f values-local.yaml
```

## 5. Observability Setup (Prometheus & Grafana)

Install `kube-prometheus-stack` (example with Helm):

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack   -n monitoring --create-namespace
```

Then apply the ServiceMonitor resources for AcmeCorp:

```bash
kubectl apply -f infra/observability/k8s/
```

Grafana (once port-forwarded or exposed) will then see metrics for:

- JVM memory & CPU (Spring Boot + Quarkus)
- HTTP request rates & latency
- Gateway traffic

You can import the dashboard JSON under:

- `infra/observability/grafana/acmecorp-jvm-http-overview.json`

into Grafana (via "Import dashboard") to get a quick platform-wide view.

## 6. Next Steps

- Integrate the React UI and point it at the gateway-service
- Extend analytics to track more events
- Configure alerts in Prometheus / Grafana
- Use this repo as the foundation for the video episodes and live demos

## Tests and smoke checks

- Backend tests: run `mvn test` inside each service directory under `services/spring-boot/*` or `services/quarkus/catalog-service`.
- Frontend tests: run `npm test` in `webapp`.
- Local smoke (docker compose up): run `make smoke-local` (or `./scripts/smoke-local.sh`) to curl the gateway endpoints.

## Makefile shortcuts and CI

- Run everything locally: `make test-all`
- Only backend or frontend: `make test-backend` or `make test-frontend`
- Local smoke with compose: `make up`, then `make smoke-local`, finish with `make down`
- GitHub Actions runs backend tests, frontend tests, and smoke tests on every push and pull request
