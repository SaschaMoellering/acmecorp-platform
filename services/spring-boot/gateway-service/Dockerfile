ARG JAVA_VERSION=21
ARG APP_NAME=app
ARG JAR_PATTERN=${APP_NAME}-*.jar

FROM maven:3.9-eclipse-temurin-${JAVA_VERSION} AS build
WORKDIR /workspace
ARG JAR_PATTERN
COPY services/spring-boot/gateway-service/pom.xml ./
RUN --mount=type=cache,target=/root/.m2 mvn -ntp -q -DskipTests -Pcrac dependency:resolve dependency:resolve-plugins
COPY services/spring-boot/gateway-service/src ./src
RUN --mount=type=cache,target=/root/.m2 mvn -ntp -q -DskipTests -Pcrac package

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
FROM azul/zulu-openjdk:21-jdk-crac-latest
WORKDIR /app
ARG APP_NAME=app
ARG JAVA_VERSION=21
ENV APP_NAME=${APP_NAME}
ENV JAVA_VERSION=${JAVA_VERSION}
ENV CRAC_MODE=off
ENV CRAC_CHECKPOINT_DIR=/opt/crac
ENV CRAC_HEALTH_PORT=8080
ENV CRAC_HEALTH_PATH=/actuator/health

RUN groupadd -r app && useradd -r -g app -d /app -s /sbin/nologin app
RUN mkdir -p /opt/app /opt/crac && chown -R app:app /opt/app /opt/crac

COPY --from=extract --chown=app:app /layers/app/dependencies/ /app/
COPY --from=extract --chown=app:app /layers/app/snapshot-dependencies/ /app/
COPY --from=extract --chown=app:app /layers/app/spring-boot-loader/ /app/
COPY --from=extract --chown=app:app /layers/app/application/ /app/

# CRaC entrypoint script (shared)
COPY infra/local/crac/crac-entrypoint.sh /opt/app/crac-entrypoint.sh
RUN chmod +x /opt/app/crac-entrypoint.sh && chown app:app /opt/app/crac-entrypoint.sh

USER app
EXPOSE 8080
ENTRYPOINT ["/opt/app/crac-entrypoint.sh"]
