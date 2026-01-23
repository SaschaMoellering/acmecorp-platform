#!/usr/bin/env bash
set -euo pipefail

echo "[require-docker] id -a: $(id -a)"

if ! command -v docker >/dev/null 2>&1; then
  echo "[require-docker] docker CLI not found in PATH." >&2
  exit 1
fi

diagnostics() {
  echo "[diagnostics] docker version" >&2
  docker version || true
  echo "[diagnostics] docker context show" >&2
  docker context show || true
  echo "[diagnostics] docker context inspect (Endpoints)" >&2
  docker context inspect "$(docker context show)" | sed -n '/Endpoints/,+20p' || true
  echo "[diagnostics] DOCKER_HOST=${DOCKER_HOST:-<unset>}" >&2
  echo "[diagnostics] /var/run/docker.sock" >&2
  ls -lah /var/run/docker.sock || true
  local rootless_sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/docker.sock"
  echo "[diagnostics] ${rootless_sock}" >&2
  ls -lah "${rootless_sock}" || true
}

try_docker_info() {
  local host="$1"
  local output
  if [ -n "${host}" ]; then
    if output="$(DOCKER_HOST="${host}" docker info 2>&1)"; then
      export DOCKER_HOST="${host}"
      return 0
    fi
  else
    if output="$(docker info 2>&1)"; then
      return 0
    fi
  fi
  echo "${output}" >&2
  return 1
}

if ! try_docker_info ""; then
  rootless_default="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/docker.sock"
  if [ -S "${rootless_default}" ] && try_docker_info "unix://${rootless_default}"; then
    echo "[require-docker] using DOCKER_HOST=${DOCKER_HOST}" >&2
  elif [ -S "$HOME/.docker/run/docker.sock" ] && try_docker_info "unix://$HOME/.docker/run/docker.sock"; then
    echo "[require-docker] using DOCKER_HOST=${DOCKER_HOST}" >&2
  else
    diagnostics
    echo "Runner user must be in docker group or use root/sudo; on GitHub Actions prefer using the hosted runner where docker works by default." >&2
    exit 1
  fi
fi

if ! docker compose version >/dev/null 2>&1; then
  diagnostics
  echo "[require-docker] docker compose version failed." >&2
  exit 1
fi
