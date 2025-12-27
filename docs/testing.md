# Testing

This project has unit tests for backend services and the webapp, plus integration tests that exercise the running Docker Compose stack.

## Unit tests

Backend unit tests (Spring Boot + Quarkus):

```bash
make test-backend
```

Frontend unit tests (Vitest):

```bash
make test-frontend
```

## Integration tests

Integration tests call the running services via HTTP, so the local stack must be up first.

```bash
make up
make test-integration
make down
```

You can override the base URL (default `http://localhost:8080`) with `ACMECORP_BASE_URL`:

```bash
ACMECORP_BASE_URL=http://localhost:8080 make test-integration
```

## Expected runtime

- Unit tests typically finish in a few minutes, depending on your machine and local caches.
- Integration tests depend on Docker startup time; the test run itself is short once services are healthy.
