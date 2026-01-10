FROM maven:3.9.9-eclipse-temurin-21 AS build
WORKDIR /workspace
COPY pom.xml .
RUN mvn -q dependency:go-offline
COPY src ./src
RUN mvn -q package -DskipTests -Dquarkus.package.type=uber-jar

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /workspace/target/*-runner.jar ./app.jar
EXPOSE 8085
CMD ["java","-jar","app.jar"]
