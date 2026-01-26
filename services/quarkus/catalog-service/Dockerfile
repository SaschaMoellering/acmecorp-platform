ARG APP_NAME=app

FROM maven:3.9.9-eclipse-temurin-21 AS build
WORKDIR /workspace
COPY pom.xml ./
RUN --mount=type=cache,target=/root/.m2 mvn -ntp -q -DskipTests -Dquarkus.package.jar.type=fast-jar dependency:resolve dependency:resolve-plugins
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn -ntp -q -DskipTests -Dquarkus.package.jar.type=fast-jar package

# CDS Archive Generation Stage for Quarkus
FROM eclipse-temurin:21-jre AS cds-gen
WORKDIR /app

COPY --from=build /workspace/target/quarkus-app/ /app/quarkus-app/

# Generate CDS archive for Quarkus
RUN set -eu; \
    echo "Generating CDS archive for Quarkus..."; \
    timeout 30s java -XX:ArchiveClassesAtExit=/tmp/app.jsa \
        -Dquarkus.http.port=0 \
        -Dquarkus.shutdown.timeout=5s \
        -jar /app/quarkus-app/quarkus-run.jar || true; \
    test -f /tmp/app.jsa && echo "CDS archive generated successfully" || echo "CDS archive generation failed"

FROM eclipse-temurin:21-jre
WORKDIR /app

ARG APP_NAME=app
ENV APP_NAME=${APP_NAME}
ENV ENABLE_CDS=true

RUN groupadd -r app && useradd -r -g app -d /app -s /sbin/nologin app && mkdir -p /app && chown -R app:app /app
RUN mkdir -p /opt/app && chown -R app:app /opt/app

COPY --from=build --chown=app:app /workspace/target/quarkus-app/ /app/quarkus-app/
COPY --from=build --chown=app:app /workspace/target/quarkus-artifact.properties /app/

# Copy CDS archive if it exists
COPY --from=cds-gen --chown=app:app /tmp/app.jsa /opt/app/app.jsa 2>/dev/null || echo "No CDS archive to copy"

RUN set -eu; \
  base='-XX:MaxRAMPercentage=75 -XX:+ExitOnOutOfMemoryError -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/tmp'; \
  printf '%s\n' "${base}" > /opt/app/jvm.options; \
  chown app:app /opt/app/jvm.options

# Create CDS-enabled startup script
RUN set -eu; \
  cat > /opt/app/start.sh << 'EOF'
#!/bin/sh
if [ "${ENABLE_CDS}" = "true" ] && [ -f "/opt/app/app.jsa" ]; then
  echo "Starting Quarkus with CDS enabled"
  exec java $(cat /opt/app/jvm.options) -Xshare:on -XX:SharedArchiveFile=/opt/app/app.jsa -jar /app/quarkus-app/quarkus-run.jar
else
  echo "Starting Quarkus without CDS"
  exec java $(cat /opt/app/jvm.options) -jar /app/quarkus-app/quarkus-run.jar
fi
EOF
  chmod +x /opt/app/start.sh; \
  chown app:app /opt/app/start.sh

USER app
EXPOSE 8080

ENTRYPOINT ["/opt/app/start.sh"]