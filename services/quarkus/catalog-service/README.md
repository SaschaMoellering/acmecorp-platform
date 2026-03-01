# Catalog Service

## Requirements

- Java 25
- Quarkus 3.31.x (managed via this service's BOM import in `pom.xml`)

## Build and Test

From this directory:

```bash
mvn -ntp clean test
```

Quick dependency sanity check:

```bash
mvn -q -DskipTests dependency:tree
```
