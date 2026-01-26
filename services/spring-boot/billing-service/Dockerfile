ARG JAVA_VERSION=21
ARG APP_NAME=app

# Use GraalVM for native compilation
FROM ghcr.io/graalvm/graalvm-community:21 AS build
WORKDIR /workspace

# Install native-image
RUN gu install native-image

# Copy Maven files
COPY pom.xml ./
RUN --mount=type=cache,target=/root/.m2 mvn -ntp -q -DskipTests dependency:resolve dependency:resolve-plugins

# Copy source and build native image
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn -ntp -Pnative native:compile -DskipTests

# Runtime stage with minimal base image
FROM gcr.io/distroless/base-debian12:nonroot
WORKDIR /app

ARG APP_NAME=app
ENV APP_NAME=${APP_NAME}

# Copy the native executable
COPY --from=build --chown=nonroot:nonroot /workspace/target/billing-service /app/app

EXPOSE 8080
ENTRYPOINT ["/app/app"]