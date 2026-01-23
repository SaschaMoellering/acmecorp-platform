#!/usr/bin/env bash
set -euo pipefail

echo "[require-docker] id -a: $(id -a)"

if ! command -v docker >/dev/null 2>&1; then
  echo "[require-docker] docker CLI not found in PATH." >&2
  exit 1
fi

if [ ! -S /var/run/docker.sock ]; then
  echo "[require-docker] docker socket not found at /var/run/docker.sock." >&2
  ls -lah /var/run/docker.sock || true
  exit 1
fi

check_docker() {
  local subcmd="$1"
  local output
  if ! output="$(docker ${subcmd} 2>&1)"; then
    if echo "${output}" | rg -i "permission denied|access denied|cannot connect to the docker daemon"; then
      echo "[require-docker] docker ${subcmd} failed: ${output}" >&2
      echo "[diagnostics] /var/run/docker.sock" >&2
      ls -lah /var/run/docker.sock || true
      echo "[diagnostics] docker group" >&2
      getent group docker || true
      echo "[diagnostics] groups" >&2
      groups || true
      echo "Runner user must be in docker group or use root/sudo; on GitHub Actions prefer using the hosted runner where docker works by default." >&2
      exit 1
    fi
    echo "[require-docker] docker ${subcmd} failed: ${output}" >&2
    exit 1
  fi
}

check_docker "version"
check_docker "info"
