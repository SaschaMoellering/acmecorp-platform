# Teleprompter Verification Analysis (Episode 5)

## Expected vs Observed

1. **Script input path**
- Expected: `/mnt/data/Teleprompter-Script-Episode-5-Polished.md` exists.
- Observed: path missing in this environment; script found at `docs/episodes/episode-05/Teleprompter-Script-Episode-5-Polished.md`.
- Status: **DEVIATION**.

2. **Compose startup and service availability**
- Expected: Compose stack starts and endpoints are reachable.
- Observed: `docker compose up -d` succeeded; containers running (`artifacts/teleprompter-evidence/C03-compose-ps.txt`).
- Observed (sandbox curl): localhost `8080/8081` unreachable from sandbox (`C04-endpoint-reachability.txt`).
- Observed (host-context curl): scenario endpoints returned `200` in host context (`C05/C06/C08` evidence).
- Status: **VERIFIED with environment caveat**.

3. **Seed data claim**
- Expected: seed creates `1000` orders, each with `5..30` items.
- Observed: seed endpoint returned `{"ordersSeeded":1000}` (`C05-seed-data.json`), but DB check shows `1000` order_items total and `min=max=1 item/order` (`C05-seed-db-check.txt`).
- Status: **DEVIATION** (items-per-order claim incorrect).

4. **N+1 endpoint behavior (`limit=5`)**
- Expected: one parent query + N child queries (`1+5`).
- Observed: endpoint returns HTTP 200 with 5 orders (`C06-nplus1-endpoint-limit5.json`). Logs show repeated child predicates `order_id=?` (`C07-nplus1-sql-evidence.log`).
- Note: SQL lines are duplicated by logging config (`spring.jpa.show-sql=true` + `org.hibernate.SQL=DEBUG`), so raw token counts are doubled.
- Status: **VERIFIED (pattern)**.

5. **Optimized endpoint behavior**
- Expected: ~1-2 queries using join/preload strategy, not N+1.
- Observed: endpoint returns HTTP 200 (`C08-optimized-endpoint.txt`), SQL evidence shows join-style query and `order_id=?` fan-out absent (`C09-optimized-sql-summary.txt`).
- Status: **VERIFIED**.

6. **Timing claim (N+1 slower than optimized)**
- Expected: N+1 slower than optimized.
- Observed: `limit=50` n+1 ~64-74ms; optimized ~15-17ms (`C06-C08-timing-comparison.txt`).
- Status: **VERIFIED (relative performance)**.

7. **Test validation command**
- Expected: `./mvnw test -Dtest=OrderServiceQueryCountTest` works.
- Observed: repo has no `mvnw`; root command fails (`127`). Equivalent module command succeeded:
  `cd services/spring-boot/orders-service && mvn -ntp test -Dtest=OrderServiceQueryCountTest`
  with `BUILD SUCCESS` (`C10-query-count-test.log`).
- Status: **DEVIATION** (command/path mismatch), test itself **verified**.

## Reproduction Notes (Exact Commands)

- Compose up:
  - `cd infra/local && docker compose up -d`
  - `cd infra/local && docker compose ps`
- Seed:
  - `curl -sS -X POST http://localhost:8080/api/gateway/seed`
- N+1 endpoint:
  - `curl -sS "http://localhost:8081/api/orders/demo/nplus1?limit=5"`
  - `cd infra/local && docker compose logs --no-color --since <timestamp> orders-service`
- Optimized endpoint:
  - `curl -sS "http://localhost:8081/api/orders/latest"`
  - `cd infra/local && docker compose logs --no-color --since <timestamp> orders-service`
- Query-count test:
  - `cd services/spring-boot/orders-service && mvn -ntp test -Dtest=OrderServiceQueryCountTest`
- Seed cardinality check:
  - `cd infra/local && docker compose exec -T postgres psql -U acmecorp -d acmecorp -c "select count(*) as orders from orders; select count(*) as order_items from order_items; select min(cnt), max(cnt), avg(cnt)::numeric(10,2) from (select order_id, count(*) cnt from order_items group by order_id) s;"`

## Likely Causes (Ranked)

1. **Docs/script drift**: teleprompter text no longer matches current seed generator (claims 5-30 items/order, data has 1).
2. **Command drift**: teleprompter assumes `./mvnw` exists at current working directory; repository/module layout requires `mvn` in service subdir.
3. **Execution-context mismatch**: sandbox cannot reach host localhost ports, while host context can; can appear as false service outage.
4. **SQL logging duplication**: `show-sql` + SQL logger causes duplicated SQL lines, inflating naive query-line counts.

## Fix Options

### Quick Workaround
- Update runbook instructions to:
  - use teleprompter path in repo (`docs/episodes/episode-05/...`),
  - run test from orders-service module with `mvn`,
  - mention host-context execution if sandboxed localhost is blocked,
  - state current seed is 1 item/order (or avoid item-range claim).

### Proper Fix
- Align implementation and script intentionally:
  - Either update seed generator to create 5-30 items/order as narrated, **or** update teleprompter narration to match current deterministic seed behavior.
  - Add a repo-level Maven wrapper if root `./mvnw ...` is expected in docs.
  - Choose one SQL logging mode (or annotate docs that duplicate lines are expected).

## Optional Patch (Docs Alignment)

```diff
diff --git a/docs/episodes/episode-05/Teleprompter-Script-Episode-5-Polished.md b/docs/episodes/episode-05/Teleprompter-Script-Episode-5-Polished.md
@@
-This creates 1000 seed orders, each with 5 to 30 items.
+This creates 1000 seed orders (current seed profile creates 1 item per order).
@@
-./mvnw test -Dtest=OrderServiceQueryCountTest
+cd services/spring-boot/orders-service
+mvn -ntp test -Dtest=OrderServiceQueryCountTest
@@
-Watch the terminal with the logs. You'll see a burst of SELECT statements.
+Watch the terminal with the logs. You'll see a burst of SELECT statements.
+Note: with both `spring.jpa.show-sql=true` and `org.hibernate.SQL=DEBUG`, SQL lines can appear duplicated in logs.
```

## UNVERIFIED Items

- None for core scenario endpoints and test execution.
- Exact absolute timing numbers in narration ("around 80-90ms" / "35-40ms") are environment-dependent; only relative trend was verified.
