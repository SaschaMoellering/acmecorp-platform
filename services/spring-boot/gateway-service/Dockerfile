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

# CDS Archive Generation Stage
FROM eclipse-temurin:${JAVA_VERSION}-jre AS cds-gen
WORKDIR /app

COPY --from=extract /layers/app/dependencies/ /app/
COPY --from=extract /layers/app/snapshot-dependencies/ /app/
COPY --from=extract /layers/app/spring-boot-loader/ /app/
COPY --from=extract /layers/app/application/ /app/

# Generate CDS archive with dry-run
RUN set -eu; \
    echo "Generating CDS archive..."; \
    timeout 30s java -XX:ArchiveClassesAtExit=/tmp/app.jsa \
        -Dspring.context.exit=onRefresh \
        org.springframework.boot.loader.launch.JarLauncher || true; \
    test -f /tmp/app.jsa && echo "CDS archive generated successfully" || echo "CDS archive generation failed"

FROM eclipse-temurin:${JAVA_VERSION}-jre
WORKDIR /app
ARG APP_NAME=app
ARG JAVA_VERSION=21
ENV APP_NAME=${APP_NAME}
ENV JAVA_VERSION=${JAVA_VERSION}
ENV ENABLE_CDS=true

RUN groupadd -r app && useradd -r -g app -d /app -s /sbin/nologin app
RUN mkdir -p /opt/app && chown -R app:app /opt/app

COPY --from=extract --chown=app:app /layers/app/dependencies/ /app/
COPY --from=extract --chown=app:app /layers/app/snapshot-dependencies/ /app/
COPY --from=extract --chown=app:app /layers/app/spring-boot-loader/ /app/
COPY --from=extract --chown=app:app /layers/app/application/ /app/

# Copy CDS archive if it exists
COPY --from=cds-gen --chown=app:app /tmp/app.jsa /opt/app/app.jsa 2>/dev/null || echo "No CDS archive to copy"

RUN set -eu; \
  base='-XX:MaxRAMPercentage=75 -XX:+ExitOnOutOfMemoryError -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/tmp'; \
  extra=''; \
  case "${JAVA_VERSION}" in \
    25) extra='-XX:+UseCompactObjectHeaders' ;; \
    *) extra='' ;; \
  esac; \
  printf '%s %s\n' "${base}" "${extra}" > /opt/app/jvm.options; \
  chown app:app /opt/app/jvm.options

# Create CDS-enabled startup script
RUN set -eu; \
  cat > /opt/app/start.sh << 'EOF'
#!/bin/sh
if [ "${ENABLE_CDS}" = "true" ] && [ -f "/opt/app/app.jsa" ]; then
  echo "Starting with CDS enabled"
  exec java $(cat /opt/app/jvm.options) -Xshare:on -XX:SharedArchiveFile=/opt/app/app.jsa org.springframework.boot.loader.launch.JarLauncher
else
  echo "Starting without CDS"
  exec java $(cat /opt/app/jvm.options) org.springframework.boot.loader.launch.JarLauncher
fi
EOF
  chmod +x /opt/app/start.sh; \
  chown app:app /opt/app/start.sh

USER app
EXPOSE 8080
ENTRYPOINT ["/opt/app/start.sh"]