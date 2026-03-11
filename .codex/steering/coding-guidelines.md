# Coding Guidelines

## Java

- Follow modern Java idioms.
- Avoid unnecessary frameworks.
- Prefer constructor injection.

## Structure

services/
  spring/
  quarkus/

Each service should remain independently buildable.

## Testing

Tests must pass before code changes are accepted.

Use:

mvn clean test
