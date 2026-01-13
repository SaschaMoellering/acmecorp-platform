FROM maven:3.9.9-eclipse-temurin-21 AS build
WORKDIR /workspace

COPY pom.xml .
RUN mvn -q dependency:go-offline

COPY src ./src
RUN mvn -q -DskipTests package -Dquarkus.package.jar.type=fast-jar

FROM eclipse-temurin:21-jre
WORKDIR /app

RUN groupadd -r app && useradd -r -g app -d /app -s /sbin/nologin app

COPY --from=build --chown=app:app /workspace/target/quarkus-app/ /app/quarkus-app/
COPY --from=build --chown=app:app /workspace/target/quarkus-artifact.properties /app/

USER app
EXPOSE 8085

ENTRYPOINT ["java", \
  "-XX:MaxRAMPercentage=75", \
  "-XX:+ExitOnOutOfMemoryError", \
  "-XX:+HeapDumpOnOutOfMemoryError", \
  "-XX:HeapDumpPath=/tmp", \
  "-jar","/app/quarkus-app/quarkus-run.jar"]