# Video Demo Script: CRaC + Warp for Java Microservices (5-10 min)

## Beat 1 - Cold Open (30-45s)

**Narration**
- "Today I’ll show how we use CRaC with Azul Warp to cut Java microservice startup time from seconds to milliseconds."
- "We’ll benchmark baseline startup, then checkpoint/restore, then export shareable results."

**On screen**
- Repo root in terminal
- `docs/crac/README.md` briefly open

## Beat 2 - Setup + Context (45-60s)

**Narration**
- "This harness runs Spring Boot services with runtime checkpoint/restore."
- "Warp is the key detail here: checkpoints are represented by `core.img`."

**On screen**
- `infra/local/crac/crac-entrypoint.sh` (highlight engine detection + warp behavior)

## Beat 3 - Baseline + Restore Benchmark (2-3 min)

**Narration**
- "Let’s run matrix mode and compare normal startup vs restore timing."

**Command**

```bash
scripts/crac-demo.sh matrix
```

**Callouts**
- In table, point at:
  - `normal_ready_ms`
  - `restore_ready_ms`
  - `restore_stats`
  - `snapshot_created=YES`
- Mention reason codes like `CHECKPOINT_WARP_OK`.

## Beat 4 - Repeats + Statistics (1-2 min)

**Narration**
- "Single restore numbers are useful, but distribution is better."

**Command**

```bash
CRAC_MATRIX_REPEATS=5 scripts/crac-demo.sh demo orders-service
```

**Callouts**
- Show `restore_stats` (`min/med/p95/max/n`)
- Explain median and p95 quickly:
  - median = typical run
  - p95 = tail latency

## Beat 5 - Functional Safety with Smoke Checks (1-2 min)

**Narration**
- "Fast restore is not enough. We should verify the app actually works."

**Command**

```bash
CRAC_MATRIX_REPEATS=5 \
CRAC_SMOKE=1 \
CRAC_SMOKE_URLS='orders-service=/actuator/health;/actuator/info' \
scripts/crac-demo.sh demo orders-service
```

**Callouts**
- Explain smoke runs inside restored container (`docker exec`, localhost:8080)
- If failing, row reason becomes `SMOKE_FAILED`

## Beat 6 - Export Artifacts for Blog/Slides (1 min)

**Narration**
- "Now let’s generate reusable artifacts: markdown, csv, summary."

**Command**

```bash
CRAC_EXPORT_DIR=/tmp/crac-results scripts/crac-bench.sh
```

**On screen**
- List output directory:

```bash
ls -lah /tmp/crac-results/*/
```

- Open:
  - `matrix.md`
  - `matrix.csv`
  - `summary.md`

**Callouts**
- "This is ready to drop into a blog post or dashboard."

## Beat 7 - Wrap (20-30s)

**Narration**
- "We measured baseline startup, validated checkpoint/restore, added smoke checks, and exported repeatable benchmark output."
- "If you want reliable Java startup improvements in containers, this is a practical CRaC + Warp workflow."

## Backup Commands (if something flakes)

```bash
CRAC_DEBUG=1 scripts/crac-demo.sh demo orders-service
```

```bash
docker compose -f infra/local/docker-compose.yml -f infra/local/docker-compose.crac.yml down -v --remove-orphans
```
