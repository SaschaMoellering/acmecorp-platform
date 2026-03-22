ARG APP_NAME=app
ARG APP_UID=10001
ARG APP_GID=10001

FROM maven:3.9.9-eclipse-temurin-21 AS build
WORKDIR /workspace
COPY pom.xml ./
RUN --mount=type=cache,target=/root/.m2 mvn -ntp -q -DskipTests -Dquarkus.package.jar.type=fast-jar dependency:resolve dependency:resolve-plugins
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn -ntp -q -DskipTests -Dquarkus.package.jar.type=fast-jar package

FROM eclipse-temurin:21-jre
WORKDIR /app

ARG APP_NAME=app
ARG APP_UID=10001
ARG APP_GID=10001
ENV APP_NAME=${APP_NAME}

RUN groupadd -g "${APP_GID}" app && useradd -u "${APP_UID}" -g app -d /app -s /sbin/nologin app && mkdir -p /app && chown -R "${APP_UID}:${APP_GID}" /app
RUN mkdir -p /opt/app && chown -R "${APP_UID}:${APP_GID}" /opt/app

COPY --from=build --chown=${APP_UID}:${APP_GID} /workspace/target/quarkus-app/ /app/quarkus-app/
COPY --from=build --chown=${APP_UID}:${APP_GID} /workspace/target/quarkus-artifact.properties /app/

RUN set -eu; \
  base='-XX:MaxRAMPercentage=75 -XX:+ExitOnOutOfMemoryError -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/tmp'; \
  printf '%s\n' "${base}" > /opt/app/jvm.options; \
  chown "${APP_UID}:${APP_GID}" /opt/app/jvm.options

USER ${APP_UID}:${APP_GID}
EXPOSE 8080

ENTRYPOINT ["sh","-c","exec java $(cat /opt/app/jvm.options) -jar /app/quarkus-app/quarkus-run.jar"]
