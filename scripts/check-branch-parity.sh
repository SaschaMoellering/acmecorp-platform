#!/usr/bin/env bash
set -euo pipefail

BASE_BRANCH="${BASE_BRANCH:-main}"
branch="$(git rev-parse --abbrev-ref HEAD)"

case "$branch" in
  java11|java17|java21|java25) ;;
  *)
    echo "[parity] Branch '$branch' is not a java* branch; skipping."
    exit 0
    ;;
 esac

if ! git show-ref --verify --quiet "refs/heads/${BASE_BRANCH}"; then
  echo "[parity] Base branch '${BASE_BRANCH}' not found locally." >&2
  exit 2
fi

allowed_regex='^(services/.+/Dockerfile|services/.+/pom\.xml|integration-tests/pom\.xml|VERSION_MATRIX\.md|docs/|bench/|scripts/|\.github/workflows/ci\.yml|\.github/workflows/backport\.yml)$'

diff_files="$(git diff --name-only "${BASE_BRANCH}..HEAD")"
if [[ -z "$diff_files" ]]; then
  echo "[parity] No diffs from ${BASE_BRANCH}."
  exit 0
fi

violations=()
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  if ! [[ "$f" =~ $allowed_regex ]]; then
    violations+=("$f")
  fi
done <<< "$diff_files"

if (( ${#violations[@]} > 0 )); then
  echo "[parity] Disallowed diffs from ${BASE_BRANCH} on ${branch}:" >&2
  printf ' - %s\n' "${violations[@]}" >&2
  exit 1
fi

echo "[parity] OK: ${branch} only changes allowed paths relative to ${BASE_BRANCH}."
