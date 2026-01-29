# syntax=docker/dockerfile:1

ARG JAVA_VERSION=21

# ----------------------------
# Build the Spring Boot jar
# ----------------------------
FROM maven:3.9-eclipse-temurin-${JAVA_VERSION} AS build
WORKDIR /workspace

COPY pom.xml ./
RUN --mount=type=cache,target=/root/.m2 mvn -ntp -q -DskipTests dependency:resolve dependency:resolve-plugins

COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn -ntp -q -DskipTests package

# Pick the "real" jar (not *.original) and copy it to a stable name
RUN set -eu; \
  ls -lah target; \
  JAR="$(ls -1 target/*.jar | grep -v '\.jar\.original$' | head -n1)"; \
  echo "Using jar: $JAR"; \
  cp "$JAR" /workspace/app.jar

# ----------------------------
# CRaC runtime (Azul Zulu CRaC JDK 21)
# ----------------------------
FROM azul/zulu-openjdk:21-jdk-crac-latest AS runner
WORKDIR /app

# Runtime controls:
# CRAC_MODE: off | checkpoint | restore
# CRAC_TRIGGER: onDemand | onRefresh
ENV CRAC_MODE=off
ENV CRAC_TRIGGER=onDemand
ENV CRAC_CHECKPOINT_DIR=/opt/crac
ENV CRAC_HEALTH_URL=http://localhost:8080/actuator/health
ENV CRAC_WARMUP_URLS=
ENV CRAC_ENGINE=warp

# JVM defaults (override at runtime via JAVA_TOOL_OPTIONS if desired)
ENV BASE_JVM_OPTS="-XX:MaxRAMPercentage=75 -XX:+ExitOnOutOfMemoryError -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/tmp"

RUN apt-get -qq update \
 && apt-get -qq install -y --no-install-recommends curl ca-certificates adduser \
 && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN addgroup --system --gid 1000 app \
 && adduser  --system --disabled-password --gecos "" --uid 1000 --gid 1000 app \
 && mkdir -p /opt/crac \
 && chown -R 1000:1000 /opt/crac /app

COPY --from=build --chown=1000:1000 /workspace/app.jar /app/app.jar

# Entrypoint
RUN cat > /opt/crac-entrypoint.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

CRAC_JVM_OPTS="-XX:+UnlockExperimentalVMOptions -XX:+UseCRaC"
if [ -n "${CRAC_ENGINE:-}" ]; then
  CRAC_JVM_OPTS="${CRAC_JVM_OPTS} -XX:CRaCEngine=${CRAC_ENGINE}"
fi

wait_for_health() {
  local url="$1"
  echo "Waiting for health: ${url}"
  for i in $(seq 1 120); do
    if curl -sf "${url}" >/dev/null 2>&1; then
      echo "Healthy after ${i}s"
      return 0
    fi
    sleep 1
  done
  echo "ERROR: Health check timed out"
  return 1
}

run_warmup() {
  if [ -z "${CRAC_WARMUP_URLS:-}" ]; then
    return 0
  fi
  echo "Warmup URLs: ${CRAC_WARMUP_URLS}"
  IFS=',' read -ra URLS <<< "${CRAC_WARMUP_URLS}"
  for url in "${URLS[@]}"; do
    url="$(echo "$url" | xargs)" || true
    [ -z "$url" ] && continue
    echo "Warmup: $url"
    curl -sf "$url" >/dev/null 2>&1 || echo "Warmup failed: $url"
  done
}

echo "CRAC_MODE=${CRAC_MODE}"
echo "CRAC_TRIGGER=${CRAC_TRIGGER}"
echo "CRAC_CHECKPOINT_DIR=${CRAC_CHECKPOINT_DIR}"
echo "CRAC_HEALTH_URL=${CRAC_HEALTH_URL}"

case "${CRAC_MODE}" in
  checkpoint)
    if [ "${CRAC_TRIGGER}" = "onRefresh" ]; then
      exec java ${BASE_JVM_OPTS} ${CRAC_JVM_OPTS} \
        -Dspring.context.checkpoint=onRefresh \
        -Djdk.crac.collect-fd-stacktraces=true \
        -XX:CRaCCheckpointTo="${CRAC_CHECKPOINT_DIR}" \
        -jar /app/app.jar
    fi

    java ${BASE_JVM_OPTS} ${CRAC_JVM_OPTS} \
      -Dspring.context.checkpoint=onDemand \
      -Djdk.crac.collect-fd-stacktraces=true \
      -jar /app/app.jar &
    APP_PID=$!

    wait_for_health "${CRAC_HEALTH_URL}"
    run_warmup
    sleep 2

    echo "Triggering checkpoint via jcmd..."
    jcmd "${APP_PID}" JDK.checkpoint || (echo "ERROR: checkpoint failed" && kill "${APP_PID}" && exit 1)

    echo "Waiting for process to exit after checkpoint..."
    wait "${APP_PID}" || true
    echo "Checkpoint complete."
    exit 0
    ;;

  restore)
    if [ ! -d "${CRAC_CHECKPOINT_DIR}" ] || [ -z "$(ls -A "${CRAC_CHECKPOINT_DIR}" 2>/dev/null || true)" ]; then
      echo "ERROR: No checkpoint found in ${CRAC_CHECKPOINT_DIR}"
      exit 1
    fi

    exec java ${BASE_JVM_OPTS} ${CRAC_JVM_OPTS} \
      -XX:CRaCRestoreFrom="${CRAC_CHECKPOINT_DIR}" \
      -jar /app/app.jar
    ;;

  *)
    exec java ${BASE_JVM_OPTS} -jar /app/app.jar
    ;;
esac
EOF

RUN chmod +x /opt/crac-entrypoint.sh && chown 1000:1000 /opt/crac-entrypoint.sh

USER 1000:1000
EXPOSE 8080
ENTRYPOINT ["/opt/crac-entrypoint.sh"]