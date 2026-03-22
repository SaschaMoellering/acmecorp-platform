# Local Setup

This guide documents the supported local developer flows for the platform.

## Local Modes

### Full Local Stack

Use Docker Compose when you want the full application locally:

```bash
cd infra/local
docker compose up --build
```

Then run the UI:

```bash
cd webapp
npm ci
npm run dev
```

### UI Against A Port-Forwarded Gateway

Use this when the backend is already running in Kubernetes and you only want a local UI:

```bash
kubectl port-forward -n acmecorp svc/acmecorp-platform-gateway-service 8080:8080

cd webapp
npm ci
npm run dev
```

The UI uses:
- origin: `http://localhost:5173`
- API base: `http://localhost:8080`

## Ports

| Component | Local URL |
| --- | --- |
| UI (Vite) | `http://localhost:5173` |
| Gateway | `http://localhost:8080` |
| Orders | `http://localhost:8081` |
| Billing | `http://localhost:8082` |
| Notification | `http://localhost:8083` |
| Analytics | `http://localhost:8084` |
| Catalog | `http://localhost:8085` |
| PostgreSQL | `localhost:5432` |
| Redis | `localhost:6379` |
| RabbitMQ | `localhost:5672` |
| RabbitMQ UI | `http://localhost:15672` |

## UI API Configuration

The UI has one source of truth for the API base URL:
- file: `webapp/src/config/api.ts`
- env var: `VITE_API_BASE_URL`

Defaults:
- `webapp/.env.development` -> `http://localhost:8080`
- `webapp/.env.production` -> `https://api.acmecorp.autoscaling.io`

Override manually if needed:

```bash
cd webapp
VITE_API_BASE_URL=http://localhost:8080 npm run dev
```

## Gateway CORS

The gateway explicitly allows:
- `http://localhost:5173`
- `http://127.0.0.1:5173`
- `http://localhost:4173`
- `http://127.0.0.1:4173`
- `https://app.acmecorp.autoscaling.io`

That keeps local UI development working without opening the policy broadly.

## Useful Local Commands

Check gateway health:

```bash
curl http://localhost:8080/api/gateway/status
```

Run frontend build:

```bash
npm --prefix webapp run build
```

Run gateway tests:

```bash
mvn -q -f services/spring-boot/gateway-service/pom.xml test
```

Run integration tests against the local stack:

```bash
cd integration-tests
mvn -q test
```
