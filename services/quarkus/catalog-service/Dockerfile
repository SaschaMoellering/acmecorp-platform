ARG APP_NAME=app

FROM maven:3.9.9-eclipse-temurin-21 AS build
WORKDIR /app
COPY pom.xml ./
RUN --mount=type=cache,target=/root/.m2 mvn -ntp -q -DskipTests -Dquarkus.package.jar.type=fast-jar dependency:resolve dependency:resolve-plugins
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn -ntp -q -DskipTests -Dquarkus.profile=appcds -Dquarkus.package.jar.type=fast-jar -Dquarkus.package.jar.appcds.enabled=true package

FROM eclipse-temurin:21-jre
WORKDIR /app

ARG APP_NAME=app
ENV APP_NAME=${APP_NAME}
ENV ENABLE_CDS=true

RUN groupadd -r app && useradd -r -g app -d /app -s /sbin/nologin app && mkdir -p /app && chown -R app:app /app
RUN mkdir -p /opt/app && chown -R app:app /opt/app

COPY --from=build --chown=app:app /app/target/quarkus-app/ /app/target/quarkus-app/
COPY --from=build --chown=app:app /app/target/quarkus-artifact.properties /app/

RUN set -eu; \
  base='-XX:MaxRAMPercentage=75 -XX:+ExitOnOutOfMemoryError -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/tmp'; \
  printf '%s\n' "${base}" > /opt/app/jvm.options; \
  chown app:app /opt/app/jvm.options

# Create CDS-enabled startup script
RUN set -eu; \
  cat > /opt/app/start.sh << 'EOF'
#!/bin/sh
if [ "${ENABLE_CDS}" = "true" ] && [ -f "/app/target/quarkus-app/app-cds.jsa" ]; then
  echo "Starting Quarkus with AppCDS enabled"
  cd /app/target/quarkus-app
  exec java $(cat /opt/app/jvm.options) -XX:SharedArchiveFile=app-cds.jsa -jar quarkus-run.jar
else
  echo "Starting Quarkus without CDS"
  exec java $(cat /opt/app/jvm.options) -jar /app/target/quarkus-app/quarkus-run.jar
fi
EOF

RUN set -eu; \
  chmod +x /opt/app/start.sh; \
  chown app:app /opt/app/start.sh

USER app
EXPOSE 8080

ENTRYPOINT ["/opt/app/start.sh"]
