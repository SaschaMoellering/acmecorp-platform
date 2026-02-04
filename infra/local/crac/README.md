# CRaC Entrypoint

`crac-entrypoint.sh` is the shared runtime entrypoint used by all Spring Boot CRaC images in this repo.

It handles:
- `CRAC_MODE=checkpoint|restore|off`
- health wait (`CRAC_HEALTH_URL` or `CRAC_HEALTH_PORT` + `CRAC_HEALTH_PATH`)
- optional warmup via `CRAC_WARMUP_URLS`
- JVM option sanitization for restore-settable constraints

## Engine behavior: Warp vs CRIU

By default these images run with Warp (`-XX:CRaCEngine=warp`).

- Warp checkpoint validity: `core.img` in `CRAC_CHECKPOINT_DIR` is sufficient.
- Warp restore command shape:
  `java -XX:CRaCEngine=warp -XX:CRaCRestoreFrom=<dir>`
- CRIU-style snapshots (if used) expect non-core checkpoint artifacts.

`criu` binary is **not required** for Warp mode.

## Usage

Build context note:

- Spring Boot CRaC images are built with compose `build.context: ../..` (repo root).
- This is required so Dockerfiles can copy the shared script:
  `COPY infra/local/crac/crac-entrypoint.sh /opt/app/crac-entrypoint.sh`.
- If context is set to a service subdirectory, builds fail with:
  `COPY ... not found`.

From repo root:

```bash
docker compose -f infra/local/docker-compose.yml -f infra/local/docker-compose.crac.yml run --rm \
  -e CRAC_MODE=checkpoint -e CRAC_CHECKPOINT_DIR=/opt/crac/orders-service orders-service

docker compose -f infra/local/docker-compose.yml -f infra/local/docker-compose.crac.yml run --rm \
  -e CRAC_MODE=restore -e CRAC_CHECKPOINT_DIR=/opt/crac/orders-service orders-service
```

Or use the helper script:

```bash
scripts/crac-demo.sh matrix
scripts/crac-demo.sh demo orders-service
```

## Troubleshooting

If you see:

```text
COPY infra/local/crac/crac-entrypoint.sh ... not found
```

check that you are building with:

```bash
docker compose -f infra/local/docker-compose.yml -f infra/local/docker-compose.crac.yml build <service>
```

and that the service build config uses repo-root context (`../..`) with dockerfile path:
`services/spring-boot/<service>/Dockerfile`.
