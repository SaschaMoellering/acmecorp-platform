#!/usr/bin/env bash
set -euo pipefail

# Placeholder harness for the Java optimizations episode.
# TODO: implement baseline + CRaC + AppCDS + Native Image runs.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RESULTS_DIR="$ROOT_DIR/bench/results"

cat <<'MSG'
TODO: Implement episode harness
- checkout episode/baseline-java21 and run baseline measurements
- checkout episode/crac-java21 and run checkpoint/restore measurements
- checkout episode/appcds-java21 and run CDS measurements
- checkout episode/native-java21 and run native image measurements
- write episode-YYYYMMDD.json and summary markdown
MSG

echo "Results will be written to: $RESULTS_DIR"
