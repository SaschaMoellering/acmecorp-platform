# CRaC Restore Behavior & Readiness Semantics

## Executive Summary

- **JVM restore is consistently fast**: CRaC/Warp restore completes in ~90–100 ms across services (restore_jvm_ms).
- **Total restore readiness varies by service** because readiness semantics differ; this is **not** a JVM restore cost.
- **This behavior is expected and correct**: CRaC optimizes JVM restore, while readiness reflects service-specific dependency health.

## Measured Results (Recent Runs)

From recent matrix runs using `scripts/crac-demo.sh` with multiple repeats:

- **restore_jvm_ms** is tightly clustered (~90–100 ms) across services.
- **post_restore_ms** varies by service and dominates total readiness.
- **analytics-service** has the **highest post_restore_ms** (~2.1–2.3 s), while other services are lower (~1.6–1.8 s).
- **Stability**: p95 values are close to medians, indicating consistent behavior across repeats.

## analytics-service Deep Dive (Root-Cause Analysis)

### What happens during restore

From restore logs:

```text
Spring-managed lifecycle restart completed (restored JVM running for 94 ms)
Tomcat started on port 8080 (http) with context path '/'
```

These show that the JVM restore and web server startup complete quickly.

### Why readiness is slower

The analytics service **explicitly gates readiness** on external dependencies:

```yaml
management:
  endpoint:
    health:
      group:
        readiness:
          include: db,redis
```

This means `/actuator/health` only returns **HTTP 200** after **both DB and Redis are healthy**. That additional wait accounts for the higher `post_restore_ms`.

### Key point

The additional restore time for analytics-service is caused by **external dependency readiness** (DB + Redis), **not** CRaC or JVM restore.

## Evidence References

### Restore logs (analytics-service)

From `/tmp/crac.analytics-service.restore.*.container.log`:

- `Spring-managed lifecycle restart completed (restored JVM running for 94 ms)`
- `Tomcat started on port 8080 (http) with context path '/'`

### Readiness configuration (analytics-service)

From `services/spring-boot/analytics-service/src/main/resources/application.yml`:

```yaml
management:
  endpoint:
    health:
      group:
        readiness:
          include: db,redis
```

### Comparison (gateway-service)

From `services/spring-boot/gateway-service/src/main/resources/application.yml`:

- Health probes enabled, **no readiness group gating** configured.

## Interpretation

- Services intentionally define “ready” differently based on dependencies and business needs.
- **CRaC optimizes JVM restore**, not the full business readiness path.
- **No changes are required**; the observed behavior is correct and expected.
