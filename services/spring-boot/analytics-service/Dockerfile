ARG JAVA_VERSION=21
ARG APP_NAME=app

# Use GraalVM for native compilation
FROM quay.io/quarkus/ubi-quarkus-mandrel-builder-image:jdk-21 AS build
USER root
RUN microdnf install -y unzip zip

USER 1001
RUN \
    curl -s "https://get.sdkman.io" | bash; \
    bash -c "source $HOME/.sdkman/bin/sdkman-init.sh; \
    sdk install maven;"

WORKDIR /workspace

# Copy Maven files
COPY pom.xml .

# Copy source and build native image

COPY src ./src

RUN bash -c "source $HOME/.sdkman/bin/sdkman-init.sh && mvn -DskipTests -ntp clean package -Pnative"

# Runtime stage with minimal base image
FROM gcr.io/distroless/base-debian12:nonroot
WORKDIR /app

ARG APP_NAME=app
ENV APP_NAME=${APP_NAME}

# Copy the native executable
COPY --from=build --chown=nonroot:nonroot /workspace/target/analytics-service /app/app

EXPOSE 8080
ENTRYPOINT ["/app/app"]