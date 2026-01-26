ARG JAVA_VERSION=11
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
    java -Djarmode=layertools -jar /tmp/app.jar extract

FROM eclipse-temurin:${JAVA_VERSION}-jre
WORKDIR /app
ARG APP_NAME=app
ARG JAVA_VERSION=11
ENV APP_NAME=${APP_NAME}
ENV JAVA_VERSION=${JAVA_VERSION}

RUN groupadd -r app && useradd -r -g app -d /app -s /sbin/nologin app
RUN mkdir -p /opt/app && chown -R app:app /opt/app

COPY --from=extract --chown=app:app /layers/dependencies/ /app/
COPY --from=extract --chown=app:app /layers/snapshot-dependencies/ /app/
COPY --from=extract --chown=app:app /layers/spring-boot-loader/ /app/
COPY --from=extract --chown=app:app /layers/application/ /app/

RUN set -eu; \
  base='-XX:MaxRAMPercentage=75 -XX:+ExitOnOutOfMemoryError -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/tmp'; \
  extra=''; \
  case "${JAVA_VERSION}" in \
    25) extra='-XX:+UseCompactObjectHeaders' ;; \
    *) extra='' ;; \
  esac; \
  printf '%s %s\n' "${base}" "${extra}" > /opt/app/jvm.options; \
  chown app:app /opt/app/jvm.options

USER app
EXPOSE 8080
ENTRYPOINT ["sh","-c","exec java $(cat /opt/app/jvm.options) org.springframework.boot.loader.JarLauncher"]