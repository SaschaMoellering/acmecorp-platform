FROM maven:3.9.9-eclipse-temurin-11 AS build
WORKDIR /workspace
COPY pom.xml .
RUN mvn -q dependency:go-offline
COPY src ./src
RUN mvn -q package -DskipTests

FROM eclipse-temurin:11-jre
WORKDIR /app
COPY --from=build /workspace/target/analytics-service-*.jar app.jar
EXPOSE 8084
ENTRYPOINT ["java","-jar","app.jar"]
