ARG JAVA_VERSION=25
ARG MAVEN_VERSION=3.9

FROM maven:${MAVEN_VERSION}-eclipse-temurin-${JAVA_VERSION} AS build
WORKDIR /workspace

COPY pom.xml ./
RUN --mount=type=cache,target=/root/.m2 \
    mvn -q -DskipTests dependency:go-offline

COPY src ./src
RUN --mount=type=cache,target=/root/.m2 \
    mvn -q -DskipTests package


FROM eclipse-temurin:${JAVA_VERSION}-jre AS extract
WORKDIR /layers

# bei dir heißt es eindeutig analytics-service-*.jar
COPY --from=build /workspace/target/analytics-service-*.jar /tmp/app.jar
RUN java -Djarmode=layertools -jar /tmp/app.jar extract


FROM eclipse-temurin:${JAVA_VERSION}-jre
WORKDIR /app

RUN set -eux; \
    groupadd -r app; \
    useradd -r -g app -d /app -s /sbin/nologin app; \
    chown -R app:app /app

# Layer order = stabiler Cache
COPY --from=extract /layers/dependencies/ /app/
COPY --from=extract /layers/snapshot-dependencies/ /app/
COPY --from=extract /layers/spring-boot-loader/ /app/
COPY --from=extract /layers/application/ /app/

USER app
EXPOSE 8084

ENTRYPOINT ["java", \
  "-XX:+UseCompactObjectHeaders", \
  "-XX:MaxRAMPercentage=75", \
  "-XX:InitialRAMPercentage=25", \
  "-XX:+ExitOnOutOfMemoryError", \
  "-XX:+HeapDumpOnOutOfMemoryError", \
  "-XX:HeapDumpPath=/tmp", \
  "org.springframework.boot.loader.launch.JarLauncher"]
