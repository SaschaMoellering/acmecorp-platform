# Analytics Service (Buildpacks/CDS/AOT)

## Runtime (unchanged)
- This service still expects real Postgres and Redis at runtime (for example via docker-compose).
- No buildpack-specific profile is enabled for normal runtime.

## Buildpack training (CDS/AOT)
The Buildpacks training run starts the app inside the builder image. To avoid requiring external DB/Redis
during that training run, you must explicitly enable the `buildpack` profile.

### Default (buildpack profile)
`spring-boot:build-image` uses the `buildpack` profile by default (via `buildpack.profiles`) so the training run
does not require external DB/Redis.
```
mvn clean spring-boot:build-image -Pappcds
```

### Override profiles for training
If you want to use normal profiles (and require DB/Redis during training), override the profile:
```
mvn clean spring-boot:build-image -Pappcds -Dbuildpack.profiles=default
```

## Guardrails
If the `buildpack` profile is active outside a buildpack environment, the app will fail fast unless the
`CNB_STACK_ID` marker is present. This prevents accidental use of buildpack-only wiring at runtime.

## Temp directory settings
`.mvn/jvm.config` pins a repo-local temp directory to avoid JNA permission issues:
- `-Djava.io.tmpdir=./.tmp`
- `-Djna.tmpdir=./.tmp`

The `.tmp` directory is created during the Maven `validate` phase.
