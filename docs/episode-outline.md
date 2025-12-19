# AcmeCorp Engineering Series – Season 1 Outline

This document links the video episodes to concrete services and infrastructure pieces
inside the AcmeCorp platform repository. Each episode is designed for **10 minutes** with
a single clear learning objective.

## Episode 1 – Platform Foundation (10 min)

**Learning Objective**: Get the AcmeCorp platform running locally

Focus:
- Architecture overview (2 min)
- Docker Compose local setup (3 min)
- Basic service interaction demo (5 min)

Code touchpoints:
- `infra/local/docker-compose.yml`
- `scripts/smoke-local.sh`
- `docs/getting-started.md`

Demo flow:
- Start Docker Compose stack
- Test gateway health endpoints
- Create and view an order
- Show all 6 services running

## Episode 2 – Microservices Deep Dive (10 min)

**Learning Objective**: Understand service architecture and communication patterns

Focus:
- Spring Boot vs Quarkus comparison (4 min)
- Service communication patterns (3 min)
- Gateway routing demo (3 min)

Code touchpoints:
- `services/spring-boot/orders-service`
- `services/quarkus/catalog-service`
- `services/spring-boot/gateway-service`
- `docs/app-architecture-and-branches.md`

Demo flow:
- Compare startup times (Spring Boot vs Quarkus)
- Show gateway routing configuration
- Trace request flow through services

## Episode 3 – Message-Driven Workflows (10 min)

**Learning Objective**: Implement event-driven architecture with RabbitMQ

Focus:
- RabbitMQ setup and concepts (3 min)
- Order → Notification flow demo (4 min)
- Frontend integration (3 min)

Code touchpoints:
- `services/spring-boot/orders-service` (NotificationPublisher)
- `services/spring-boot/notification-service` (NotificationListener)
- `webapp/src/components/Notifications.tsx`
- `docs/notification-system.md`

Demo flow:
- Create order → Confirm order → View notification
- Show RabbitMQ management UI
- Demonstrate React frontend integration

## Episode 4 – Database & Performance (10 min)

**Learning Objective**: Optimize data access patterns and caching

Focus:
- Hibernate N+1 problem demo (4 min)
- Redis caching patterns (3 min)
- Performance comparison (3 min)

Code touchpoints:
- `services/spring-boot/orders-service` (OrderService N+1 demo)
- Redis integration across services
- `bench/` performance testing scripts

Demo flow:
- Show N+1 query problem
- Implement batch loading fix
- Demonstrate Redis caching benefits

## Episode 5 – Kubernetes Deployment (10 min)

**Learning Objective**: Deploy microservices to Kubernetes with Helm

Focus:
- Helm chart walkthrough (3 min)
- Production deployment demo (4 min)
- Service discovery and networking (3 min)

Code touchpoints:
- `helm/acmecorp-platform/`
- `infra/k8s/base/`
- `scripts/validate-k8s.sh`

Demo flow:
- Deploy with Helm to local Kubernetes
- Show service discovery in action
- Validate deployment health

## Episode 6 – Production Security (10 min)

**Learning Objective**: Implement Kubernetes security best practices

Focus:
- Network policies demo (3 min)
- Secrets management (3 min)
- Resource limits and quotas (4 min)

Code touchpoints:
- `infra/k8s/base/network-policies.yaml`
- `infra/k8s/base/sealed-secrets-controller.yaml`
- `infra/k8s/base/resource-quota.yaml`
- `infra/k8s/base/pod-disruption-budgets.yaml`

Demo flow:
- Apply network policies and test isolation
- Create sealed secrets
- Show resource quota enforcement

## Episode 7 – Observability (10 min)

**Learning Objective**: Monitor and troubleshoot microservices

Focus:
- Metrics and monitoring setup (4 min)
- Grafana dashboards walkthrough (3 min)
- Troubleshooting demo (3 min)

Code touchpoints:
- `infra/observability/k8s/*-servicemonitor.yaml`
- `infra/observability/grafana/acmecorp-jvm-http-overview.json`
- Spring Boot Actuator endpoints

Demo flow:
- Set up Prometheus and Grafana
- Show JVM and HTTP metrics
- Demonstrate troubleshooting workflow

## Episode 8 – Cloud Native Scaling (10 min)

**Learning Objective**: Scale microservices in production cloud environment

Focus:
- EKS Auto Mode deployment (4 min)
- Load testing and scaling (3 min)
- Cost optimization (3 min)

Code touchpoints:
- `infra/terraform/` (AWS infrastructure)
- `helm/acmecorp-platform/values-prod.yaml`
- `bench/` load testing scripts

Demo flow:
- Deploy to EKS Auto Mode
- Run load tests and observe scaling
- Show cost optimization features

## Services and Episodes Matrix

| Component           | Ep1 | Ep2 | Ep3 | Ep4 | Ep5 | Ep6 | Ep7 | Ep8 |
|---------------------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| orders-service      |  X  |  X  |  X  |  X  |  X  |     |  X  |  X  |
| billing-service     |  X  |  X  |     |     |  X  |     |  X  |  X  |
| notification-service|  X  |     |  X  |     |  X  |     |  X  |  X  |
| analytics-service   |  X  |  X  |     |  X  |  X  |     |  X  |  X  |
| catalog-service     |  X  |  X  |     |  X  |  X  |     |  X  |  X  |
| gateway-service     |  X  |  X  |  X  |     |  X  |     |  X  |  X  |
| webapp (React)      |     |     |  X  |     |     |     |     |     |
| RabbitMQ            |     |     |  X  |     |  X  |     |  X  |  X  |
| Redis               |  X  |     |     |  X  |  X  |     |  X  |  X  |
| PostgreSQL          |  X  |     |     |  X  |  X  |     |  X  |  X  |
| Kubernetes          |     |     |     |     |  X  |  X  |  X  |  X  |
| Security Policies   |     |     |     |     |     |  X  |     |  X  |

## Episode Time Breakdown

Each episode follows a consistent 10-minute structure:
- **Introduction** (1 min): Learning objective and context
- **Core Content** (7-8 min): Hands-on demonstration
- **Wrap-up** (1-2 min): Key takeaways and next episode preview