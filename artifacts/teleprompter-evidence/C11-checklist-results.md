# Checklist Execution Results

- C01-script-path: DEVIATION (input path missing; repo path used)
- C02-compose-dir-detect: VERIFIED (`infra/local`)
- C03-compose-up: VERIFIED
- C04-endpoint-reachability: DEVIATION in sandbox (UNREACHABLE); host-context calls succeeded
- C05-seed-data: PARTIAL DEVIATION (1000 orders verified; 5-30 items/order claim failed)
- C06-nplus1-endpoint-limit5: VERIFIED
- C07-nplus1-sql-evidence: VERIFIED (1+N pattern, with duplicated SQL lines due logging config)
- C08-optimized-endpoint: VERIFIED
- C09-optimized-sql-evidence: VERIFIED (~2 effective queries; no per-order `order_id=?` fan-out)
- C10-query-count-test: DEVIATION for command path (`./mvnw` missing), VERIFIED for equivalent module test execution (pass)
- C11-claim-vs-observed-analysis: VERIFIED (`artifacts/teleprompter-analysis.md`)
