# Local Architecture (Docker Compose)

## Goals

The local architecture is designed to make development fast, predictable, and close to production behavior while remaining easy to run on a laptop. Docker Compose provides a single, repeatable stack with explicit service wiring and well-known ports.

## Diagram

![Local Docker Compose architecture](docker-compose.svg)

Source: [`docker-compose.mmd`](docker-compose.mmd)

## Components

- **Webapp**: React + Vite SPA that calls the gateway API. It is not part of the Docker Compose stack by default and runs locally on port `5173`.
- **API / services**: The gateway-service fronts the backend and routes requests to the domain services (orders, billing, notification, analytics, catalog). All services run as Docker containers in the Compose stack.
- **Postgres**: Primary relational database used by the services for durable data storage.
- **Redis**: Cache and shared data store used by services for low-latency reads and application coordination.
- **RabbitMQ**: Message broker used for asynchronous communication between services (e.g., notifications).

## Stateless vs stateful

- **Stateless**: Webapp, gateway-service, and all domain services are stateless containers; they can be scaled or restarted without losing data.
- **Stateful**: Postgres, Redis, and RabbitMQ maintain state. Their data lives in Docker volumes and must be treated as persistent.

## Moving to AWS/EKS (high level)

The service topology stays the same, but runtime responsibilities shift to managed infrastructure. The gateway and domain services move to Kubernetes deployments, while stateful components typically move to managed services (e.g., managed Postgres, Redis, and RabbitMQ). Networking and ingress replace Docker Compose port mappings, and configuration moves to Kubernetes resources and environment variables.
