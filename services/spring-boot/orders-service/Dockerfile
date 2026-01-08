ARG JAVA_VERSION=25
ARG MAVEN_VERSION=3.9.9
FROM eclipse-temurin:${JAVA_VERSION}-jdk AS build
ARG MAVEN_VERSION
RUN set -e; \
    apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl; \
    MAVEN_TGZ=apache-maven-${MAVEN_VERSION}-bin.tar.gz; \
    curl -fsSL "https://repo.maven.apache.org/maven2/org/apache/maven/apache-maven/${MAVEN_VERSION}/${MAVEN_TGZ}" -o /tmp/maven.tar.gz; \
    tar -xzf /tmp/maven.tar.gz -C /opt; \
    ln -s /opt/apache-maven-${MAVEN_VERSION}/bin/mvn /usr/local/bin/mvn; \
    rm -f /tmp/maven.tar.gz; \
    apt-get purge -y --auto-remove curl; \
    rm -rf /var/lib/apt/lists/*
WORKDIR /workspace
COPY pom.xml .
RUN mvn -q dependency:go-offline
COPY src ./src
RUN mvn -q package -DskipTests

FROM eclipse-temurin:${JAVA_VERSION}-jre
WORKDIR /app
COPY --from=build /workspace/target/orders-service-*.jar app.jar
EXPOSE 8081
ENTRYPOINT ["java","-jar","app.jar"]
