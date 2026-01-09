# Java 11 (Spring Boot services)

This branch targets Java 11 for Spring Boot services. Quarkus catalog is not part of the Java 11 build/run path.

## Requirements

- JDK 11 for Spring Boot service builds (Dockerfiles use Java 11 images).
- Docker + Docker Compose for local stack.

## Build (Spring Boot only)

From repo root:

- Build tests for Spring services:
  - `for svc in services/spring-boot/*; do (cd "$svc" && mvn -q test); done`
- Package Spring services:
  - `for svc in services/spring-boot/*; do (cd "$svc" && mvn -q package -DskipTests); done`

## Run (Docker Compose)

1. `cd infra/local && docker compose up -d --build`
2. Check health:
   - `curl -sSf http://localhost:8080/actuator/health`
   - `curl -sSf http://localhost:8081/actuator/health`
   - `curl -sSf http://localhost:8082/actuator/health`
   - `curl -sSf http://localhost:8083/actuator/health`
   - `curl -sSf http://localhost:8084/actuator/health`
3. `cd infra/local && docker compose down`

## Notes

- Quarkus catalog (`services/quarkus/catalog-service`) requires a newer Java runtime and is excluded from Java 11 expectations on this branch.
