#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <commit-sha> [branches...]" >&2
  echo "Example: $0 abc123 java25 java21 java17 java11" >&2
}

if [[ $# -lt 1 ]]; then
  usage
  exit 2
fi

commit_sha="$1"
shift || true

branches=(java25 java21 java17 java11)
if [[ $# -gt 0 ]]; then
  if [[ $# -eq 1 ]]; then
    read -r -a branches <<<"$1"
  else
    branches=("$@")
  fi
fi

repo_root="$(git rev-parse --show-toplevel)"
cd "${repo_root}"

log() {
  printf '[backport] %s\n' "$*"
}

fail() {
  printf '[backport] ERROR: %s\n' "$*" >&2
}

if ! git cat-file -e "${commit_sha}^{commit}" 2>/dev/null; then
  fail "Commit ${commit_sha} not found."
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  fail "Working tree is not clean. Commit or stash changes before running backport."
  exit 1
fi

log "Fetching remotes"
git fetch --all --prune

for branch in "${branches[@]}"; do
  if ! git show-ref --verify --quiet "refs/remotes/origin/${branch}"; then
    fail "Remote branch origin/${branch} not found."
    exit 1
  fi
done

start_branch="$(git symbolic-ref --short HEAD 2>/dev/null || true)"
results=()

select_test_cmd() {
  if [[ -x "${repo_root}/mvnw" ]]; then
    echo "mvnw"
    return 0
  fi

  if [[ -f "${repo_root}/Makefile" ]] && grep -qE '^test-backend:' "${repo_root}/Makefile"; then
    echo "make"
    return 0
  fi

  return 1
}

run_tests() {
  local cmd
  if ! cmd="$(select_test_cmd)"; then
    fail "No fast test command found (expected ./mvnw or Makefile target test-backend)."
    return 1
  fi

  if [[ "${cmd}" == "mvnw" ]]; then
    log "Running tests: ./mvnw -q -DskipITs -DskipTests=false test"
    ./mvnw -q -DskipITs -DskipTests=false test
  else
    log "Running tests: make test-backend"
    make test-backend
  fi
}

is_whitespace_only_conflict() {
  local file="$1"
  local ours
  local theirs

  ours="$(mktemp)"
  theirs="$(mktemp)"

  if ! git show ":2:${file}" >"${ours}" 2>/dev/null; then
    rm -f "${ours}" "${theirs}"
    return 1
  fi
  if ! git show ":3:${file}" >"${theirs}" 2>/dev/null; then
    rm -f "${ours}" "${theirs}"
    return 1
  fi

  if diff -q -w -B "${ours}" "${theirs}" >/dev/null 2>&1; then
    rm -f "${ours}" "${theirs}"
    return 0
  fi

  rm -f "${ours}" "${theirs}"
  return 1
}

for branch in "${branches[@]}"; do
  log "Processing ${branch}"
  git checkout "${branch}"
  git pull --ff-only

  if ! git cherry-pick -x "${commit_sha}"; then
    mapfile -t conflicts < <(git diff --name-only --diff-filter=U)
    if [[ ${#conflicts[@]} -eq 0 ]]; then
      fail "Cherry-pick failed for ${branch} without merge conflicts. Resolve manually."
      results+=("${branch}:failed")
      exit 1
    fi

    log "Conflicts detected: ${conflicts[*]}"
    unresolved=()
    for file in "${conflicts[@]}"; do
      if is_whitespace_only_conflict "${file}"; then
        log "Auto-resolving whitespace-only conflict (theirs): ${file}"
        git checkout --theirs -- "${file}"
        git add "${file}"
      else
        unresolved+=("${file}")
      fi
    done

    if [[ ${#unresolved[@]} -gt 0 ]]; then
      fail "Unresolved conflicts in: ${unresolved[*]}"
      fail "Resolve manually, then run: git cherry-pick --continue"
      results+=("${branch}:conflicts")
      exit 1
    fi

    git cherry-pick --continue
  fi

  if ! run_tests; then
    fail "Tests failed on ${branch}. Aborting cherry-pick."
    git cherry-pick --abort
    results+=("${branch}:tests_failed")
    exit 1
  fi

  log "Pushing ${branch}"
  git push origin "${branch}"
  results+=("${branch}:success")
  log "Done with ${branch}"
  echo

done

if [[ -n "${start_branch}" ]]; then
  git checkout "${start_branch}" >/dev/null 2>&1 || true
fi

log "Summary"
for result in "${results[@]}"; do
  printf '  - %s\n' "${result}"
  if [[ "${result}" != *":success" ]]; then
    exit 1
  fi
done
