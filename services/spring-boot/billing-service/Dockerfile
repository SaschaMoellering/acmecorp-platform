ARG JAVA_VERSION=21
ARG APP_NAME=app
ARG JAR_PATTERN=${APP_NAME}-*.jar

FROM maven:3.9-eclipse-temurin-${JAVA_VERSION} AS build
WORKDIR /workspace
ARG JAR_PATTERN
COPY pom.xml ./
RUN --mount=type=cache,target=/root/.m2 mvn -ntp -q -DskipTests dependency:resolve dependency:resolve-plugins
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn -ntp -q -DskipTests package

FROM eclipse-temurin:${JAVA_VERSION}-jre AS extract
WORKDIR /layers

COPY --from=build /workspace/target/ /tmp/target/

RUN set -eu; \
    echo "== target listing =="; ls -lah /tmp/target; \
    echo "== jar candidates =="; ls -1 /tmp/target/*.jar; \
    JAR="$(ls -1 /tmp/target/*.jar | grep -v '\.jar\.original$' | head -n1)"; \
    echo "Using jar: ${JAR}"; \
    cp "${JAR}" /tmp/app.jar; \
    test -f /tmp/app.jar; \
    java -Djarmode=tools -jar /tmp/app.jar extract --layers --launcher

# CRaC-enabled runtime with Azul Zulu CRaC build
FROM azul/zulu-openjdk:21-crac
WORKDIR /app
ARG APP_NAME=app
ARG JAVA_VERSION=21
ENV APP_NAME=${APP_NAME}
ENV JAVA_VERSION=${JAVA_VERSION}
ENV CRAC_MODE=off
ENV CRAC_CHECKPOINT_DIR=/opt/crac

RUN groupadd -r app && useradd -r -g app -d /app -s /sbin/nologin app
RUN mkdir -p /opt/app /opt/crac && chown -R app:app /opt/app /opt/crac

COPY --from=extract --chown=app:app /layers/app/dependencies/ /app/
COPY --from=extract --chown=app:app /layers/app/snapshot-dependencies/ /app/
COPY --from=extract --chown=app:app /layers/app/spring-boot-loader/ /app/
COPY --from=extract --chown=app:app /layers/app/application/ /app/

# Create CRaC entrypoint script
RUN cat > /opt/app/crac-entrypoint.sh << 'EOF'
#!/bin/bash
set -euo pipefail

# JVM options for CRaC
CRAC_JVM_OPTS="-XX:+UnlockExperimentalVMOptions -XX:+UseCRaC"
BASE_JVM_OPTS="-XX:MaxRAMPercentage=75 -XX:+ExitOnOutOfMemoryError -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/tmp"

case "${CRAC_MODE}" in
  "checkpoint")
    echo "Starting in checkpoint mode..."
    echo "Checkpoint directory: ${CRAC_CHECKPOINT_DIR}"
    
    # Start application in background
    java ${BASE_JVM_OPTS} ${CRAC_JVM_OPTS} org.springframework.boot.loader.launch.JarLauncher &
    APP_PID=$!
    
    # Wait for health endpoint
    echo "Waiting for application to be ready..."
    for i in {1..60}; do
      if curl -sf http://localhost:8082/actuator/health > /dev/null 2>&1; then
        echo "Application is ready after ${i} seconds"
        break
      fi
      sleep 1
    done
    
    # Execute warmup requests if configured
    if [ -n "${CRAC_WARMUP_URLS:-}" ]; then
      echo "Executing warmup requests..."
      IFS=',' read -ra URLS <<< "$CRAC_WARMUP_URLS"
      for url in "${URLS[@]}"; do
        echo "Warming up: $url"
        curl -sf "$url" > /dev/null 2>&1 || echo "Warmup failed for $url"
      done
    fi
    
    # Give application time to settle
    sleep 5
    
    # Create checkpoint
    echo "Creating checkpoint..."
    jcmd $APP_PID JDK.checkpoint
    
    # Wait for process to exit
    wait $APP_PID
    echo "Checkpoint created successfully"
    ;;
    
  "restore")
    echo "Starting in restore mode..."
    echo "Checkpoint directory: ${CRAC_CHECKPOINT_DIR}"
    
    if [ ! -d "${CRAC_CHECKPOINT_DIR}" ] || [ -z "$(ls -A ${CRAC_CHECKPOINT_DIR})" ]; then
      echo "ERROR: No checkpoint found in ${CRAC_CHECKPOINT_DIR}"
      exit 1
    fi
    
    # Restore from checkpoint
    exec java ${BASE_JVM_OPTS} ${CRAC_JVM_OPTS} -XX:CRaCRestoreFrom=${CRAC_CHECKPOINT_DIR} org.springframework.boot.loader.launch.JarLauncher
    ;;
    
  *)
    echo "Starting in normal mode (no CRaC)..."
    exec java ${BASE_JVM_OPTS} org.springframework.boot.loader.launch.JarLauncher
    ;;
esac
EOF

RUN chmod +x /opt/app/crac-entrypoint.sh && chown app:app /opt/app/crac-entrypoint.sh

USER app
EXPOSE 8080
ENTRYPOINT ["/opt/app/crac-entrypoint.sh"]