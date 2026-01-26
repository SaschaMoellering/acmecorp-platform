# Java Optimizations Overview

This document outlines the Java services in the AcmeCorp Platform and their participation in optimization strategies.

## Service Inventory

### Spring Boot Services (JVM-based)
All Spring Boot services use Maven, Java 21, and expose health endpoints on `/actuator/health`.

| Service | Port | Build Tool | Runtime | CDS Support | GraalVM Native Support |
|---------|------|------------|---------|-------------|------------------------|
| **gateway-service** | 8080 | Maven | Spring Boot 3.3.4 | ✅ | ✅ |
| **orders-service** | 8081 | Maven | Spring Boot 3.3.4 | ✅ | ✅ |
| **billing-service** | 8082 | Maven | Spring Boot 3.3.4 | ✅ | ✅ |
| **notification-service** | 8083 | Maven | Spring Boot 3.3.4 | ✅ | ✅ |
| **analytics-service** | 8084 | Maven | Spring Boot 3.3.4 | ✅ | ✅ |

### Quarkus Services
| Service | Port | Build Tool | Runtime | CDS Support | GraalVM Native Support |
|---------|------|------------|---------|-------------|------------------------|
| **catalog-service** | 8085 | Maven | Quarkus 3.15.0 | ✅ (AppCDS only) | ✅ |

## Optimization Strategies

### Class Data Sharing (CDS)
- **Target**: All services (Spring Boot + Quarkus)
- **Benefit**: Reduced JVM startup time and memory usage
- **Implementation**: AppCDS archives generated during Docker build
- **Toggle**: `ENABLE_CDS=true|false` environment variable

### GraalVM Native Image
- **Target**: All services
- **Benefit**: Minimal startup time and memory footprint
- **Implementation**: 
  - Spring Boot: Spring AOT + GraalVM Native Build Tools
  - Quarkus: Built-in native compilation support
- **Runtime**: Distroless/scratch containers

## Branch Strategy

- **main**: Standard JVM builds (baseline)
- **cds**: JVM builds with CDS optimization
- **graalvm**: Native image builds

## Health Endpoints

All services maintain their health endpoints:
- Spring Boot: `/actuator/health`
- Quarkus: `/q/health`

Ports and external contracts remain unchanged across all optimization branches.