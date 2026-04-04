# Getting Started (Compatibility Entry Point)

The canonical onboarding docs now live in:

- [docs/README.md](README.md)
- [docs/getting-started/quickstart.md](getting-started/quickstart.md)
- [docs/development/local-setup.md](development/local-setup.md)

This file is retained only as a compatibility entry point for older links.

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
