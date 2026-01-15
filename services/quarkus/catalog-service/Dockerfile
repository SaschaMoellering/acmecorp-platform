# syntax=docker/dockerfile:1.7

ARG MAVEN_VERSION=3.9
ARG JAVA_VERSION=21

FROM maven:${MAVEN_VERSION}-eclipse-temurin-21 AS build
WORKDIR /workspace

ENV MAVEN_OPTS="-Dmaven.repo.local=/root/.m2/repository" \
    MAVEN_CLI_OPTS="-q -DskipTests -Dquarkus.package.jar.type=fast-jar"

COPY pom.xml ./

RUN --mount=type=cache,target=/root/.m2 \
    mvn ${MAVEN_CLI_OPTS} package || true

COPY src ./src

RUN --mount=type=cache,target=/root/.m2 \
    mvn ${MAVEN_CLI_OPTS} package

FROM eclipse-temurin:21-jre
WORKDIR /app

RUN set -eux; \
    groupadd -r app; \
    useradd -r -g app -d /app -s /sbin/nologin app; \
    mkdir -p /app /tmp; \
    chown -R app:app /app /tmp

COPY --from=build --chown=app:app /workspace/target/quarkus-app/ /app/quarkus-app/
COPY --from=build --chown=app:app /workspace/target/quarkus-artifact.properties /app/

USER app
EXPOSE 8085

ENTRYPOINT ["java", \
  "-XX:MaxRAMPercentage=75", \
  "-XX:InitialRAMPercentage=25", \
  "-XX:+ExitOnOutOfMemoryError", \
  "-XX:+HeapDumpOnOutOfMemoryError", \
  "-XX:HeapDumpPath=/tmp", \
  "-Djava.security.egd=file:/dev/urandom", \
  "-jar","/app/quarkus-app/quarkus-run.jar"]