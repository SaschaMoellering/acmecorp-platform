ARG APP_NAME=app

FROM maven:3.9.9-eclipse-temurin-25 AS build
WORKDIR /workspace
COPY pom.xml ./
RUN --mount=type=cache,target=/root/.m2 mvn -ntp -q -DskipTests -Dquarkus.package.jar.type=fast-jar dependency:resolve dependency:resolve-plugins
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn -ntp -q -DskipTests -Dquarkus.package.jar.type=fast-jar package

FROM eclipse-temurin:25-jre
WORKDIR /app

ARG APP_NAME=app
ENV APP_NAME=${APP_NAME}

RUN groupadd -r app && useradd -r -g app -d /app -s /sbin/nologin app && mkdir -p /app && chown -R app:app /app
RUN mkdir -p /opt/app && chown -R app:app /opt/app

COPY --from=build --chown=app:app /workspace/target/quarkus-app/ /app/quarkus-app/
COPY --from=build --chown=app:app /workspace/target/quarkus-artifact.properties /app/

RUN set -eu; \
  base='-XX:MaxRAMPercentage=75 -XX:+ExitOnOutOfMemoryError -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/tmp'; \
  printf '%s\n' "${base}" > /opt/app/jvm.options; \
  chown app:app /opt/app/jvm.options

USER app
EXPOSE 8080

ENTRYPOINT ["sh","-c","exec java $(cat /opt/app/jvm.options) -jar /app/quarkus-app/quarkus-run.jar"]