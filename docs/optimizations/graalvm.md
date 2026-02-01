# GraalVM Native Image Optimization

This document describes the GraalVM native image implementation for AcmeCorp Platform services.

## Overview

GraalVM Native Image compiles Java applications ahead-of-time into native executables, providing:
- Instant startup (milliseconds vs seconds)
- Lower memory footprint
- No JVM overhead

## Implementation

### Spring Boot Services
- **Services**: gateway, orders, billing, notification, analytics
- **Build Tools**: GraalVM Native Build Tools + Spring AOT
- **Maven Profile**: `-Pnative` for native compilation
- **Runtime**: Distroless container (gcr.io/distroless/base-debian12)

### Quarkus Service
- **Service**: catalog
- **Build**: Built-in Quarkus native support with `-Dnative`
- **Runtime**: Distroless container

## Docker Build Process

1. **Build Stage**: 
   - Use GraalVM Community Edition 21
   - Install native-image tool
   - Compile to native executable
2. **Runtime Stage**:
   - Minimal distroless base image
   - Copy native executable only
   - No JVM required

## Build Commands

### Spring Boot Services
```bash
# Build native image
mvn -Pnative clean package -DskipTests

# Docker build
docker build -t service-name:native .
```

### Quarkus Service
```bash
# Build native image
mvn -Pnative package -DskipTests

# Docker build
docker build -t catalog-service:native .
```

## Runtime Characteristics

### Startup Time
- **JVM**: 5-15 seconds
- **Native**: 50-200 milliseconds

### Memory Usage
- **JVM**: 200-500 MB
- **Native**: 50-150 MB

### Image Size
- **JVM**: 200-400 MB
- **Native**: 50-100 MB

## Configuration

### Spring Boot AOT Processing
The Spring Boot services use AOT (Ahead-of-Time) processing to:
- Pre-compute reflection metadata
- Generate native configuration
- Optimize for native compilation

### Native Build Configuration
```xml
<plugin>
  <groupId>org.graalvm.buildtools</groupId>
  <artifactId>native-maven-plugin</artifactId>
  <configuration>
    <fallback>false</fallback>
    <verbose>true</verbose>
  </configuration>
</plugin>
```

## Health Endpoints

All services maintain their health endpoints in native mode:
- Spring Boot: `/actuator/health`
- Quarkus: `/q/health`

## Known Limitations

### Reflection
- Dynamic class loading not supported
- Reflection requires compile-time configuration
- Some libraries may not be compatible

### Runtime Behavior
- No JIT compilation
- No dynamic optimization
- Fixed memory allocation

### Build Time
- Native compilation is slower (5-15 minutes vs 1-2 minutes)
- Requires more build resources (CPU/Memory)

## Troubleshooting

### Build Failures
```bash
# Check native-image is installed
native-image --version

# Verbose build output
mvn -Pnative clean package -DskipTests -X
```

### Runtime Issues
```bash
# Check executable permissions
ls -la target/service-name

# Test native executable directly
./target/service-name
```

### Missing Reflection Configuration
If you encounter reflection errors:
1. Use GraalVM tracing agent during development
2. Add reflection configuration to `META-INF/native-image/`
3. Use Spring Boot's AOT processing

## Performance Tuning

### Build Optimization
- Use build cache for Maven dependencies
- Parallel native compilation: `-J-XX:+UseParallelGC`
- Memory for build: `-J-Xmx8g`

### Runtime Optimization
- Native executables are pre-optimized
- No JVM tuning parameters needed
- Container resource limits apply directly

## Development Workflow

1. **Development**: Use JVM mode for faster iteration
2. **Testing**: Build native for integration tests
3. **Production**: Deploy native images

```bash
# Development (fast)
mvn spring-boot:run

# Native build (slower, production-ready)
mvn -Pnative clean package -DskipTests
```
