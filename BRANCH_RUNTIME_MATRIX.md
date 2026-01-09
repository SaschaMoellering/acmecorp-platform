# Branch Runtime Matrix
## Summary
Analyzed branches: java11, java17, java21, java25, main

Notes:
- Java targets derived from POM properties/plugins in precedence order (release, plugin release, java.version, plugin source/target).
- Docker images are read from Dockerfiles when present.
- Quarkus exclusion is inferred from Makefile targets.

## java11
| service path | framework | framework version | java target | docker base image | notes |
| --- | --- | --- | --- | --- | --- |
| services/spring-boot/orders-service | Spring Boot | 2.7.18 | 11 | build=maven:3.9.9-eclipse-temurin-11; runtime=eclipse-temurin:11-jre |  |
| services/spring-boot/billing-service | Spring Boot | 2.7.18 | 11 | build=maven:3.9.9-eclipse-temurin-11; runtime=eclipse-temurin:11-jre |  |
| services/spring-boot/notification-service | Spring Boot | 2.7.18 | 11 | build=maven:3.9.9-eclipse-temurin-11; runtime=eclipse-temurin:11-jre |  |
| services/spring-boot/analytics-service | Spring Boot | 2.7.18 | 11 | build=maven:3.9.9-eclipse-temurin-11; runtime=eclipse-temurin:11-jre |  |
| services/spring-boot/gateway-service | Spring Boot | 2.7.18 | 11 | build=maven:3.9.9-eclipse-temurin-11; runtime=eclipse-temurin:11-jre |  |
| services/quarkus/catalog-service | Quarkus | 3.15.0 | build=21; runtime=21 | build=maven:3.9.9-eclipse-temurin-21; runtime=eclipse-temurin:21-jre | excluded from Makefile targets; Quarkus 3.x requires Java 17+; not compatible with Java 11 baseline; java target derived from Dockerfile |

## java17
| service path | framework | framework version | java target | docker base image | notes |
| --- | --- | --- | --- | --- | --- |
| services/spring-boot/orders-service | Spring Boot | 3.3.4 | 17 | build=maven:3.9.9-eclipse-temurin-17; runtime=eclipse-temurin:17-jre |  |
| services/spring-boot/billing-service | Spring Boot | 3.3.4 | 17 | build=maven:3.9.9-eclipse-temurin-17; runtime=eclipse-temurin:17-jre |  |
| services/spring-boot/notification-service | Spring Boot | 3.3.4 | 17 | build=maven:3.9.9-eclipse-temurin-17; runtime=eclipse-temurin:17-jre |  |
| services/spring-boot/analytics-service | Spring Boot | 3.3.4 | 17 | build=maven:3.9.9-eclipse-temurin-17; runtime=eclipse-temurin:17-jre |  |
| services/spring-boot/gateway-service | Spring Boot | 3.3.4 | 17 | build=maven:3.9.9-eclipse-temurin-17; runtime=eclipse-temurin:17-jre |  |
| services/quarkus/catalog-service | Quarkus | 3.15.0 | build=17; runtime=17 | build=maven:3.9.9-eclipse-temurin-17; runtime=eclipse-temurin:17-jre | java target derived from Dockerfile |

## java21
| service path | framework | framework version | java target | docker base image | notes |
| --- | --- | --- | --- | --- | --- |
| services/spring-boot/orders-service | Spring Boot | 3.3.4 | 21 | build=maven:3.9.9-eclipse-temurin-21; runtime=eclipse-temurin:21-jre |  |
| services/spring-boot/billing-service | Spring Boot | 3.3.4 | 21 | build=maven:3.9.9-eclipse-temurin-21; runtime=eclipse-temurin:21-jre |  |
| services/spring-boot/notification-service | Spring Boot | 3.3.4 | 21 | build=maven:3.9.9-eclipse-temurin-21; runtime=eclipse-temurin:21-jre |  |
| services/spring-boot/analytics-service | Spring Boot | 3.3.4 | 21 | build=maven:3.9.9-eclipse-temurin-21; runtime=eclipse-temurin:21-jre |  |
| services/spring-boot/gateway-service | Spring Boot | 3.3.4 | 21 | build=maven:3.9.9-eclipse-temurin-21; runtime=eclipse-temurin:21-jre |  |
| services/quarkus/catalog-service | Quarkus | 3.15.0 | build=21; runtime=21 | build=maven:3.9.9-eclipse-temurin-21; runtime=eclipse-temurin:21-jre | java target derived from Dockerfile |

## java25
| service path | framework | framework version | java target | docker base image | notes |
| --- | --- | --- | --- | --- | --- |
| services/spring-boot/orders-service | Spring Boot | 4.0.1 | 25 | build=eclipse-temurin:${JAVA_VERSION}-jdk; runtime=eclipse-temurin:${JAVA_VERSION}-jre |  |
| services/spring-boot/billing-service | Spring Boot | 4.0.1 | 25 | build=eclipse-temurin:${JAVA_VERSION}-jdk; runtime=eclipse-temurin:${JAVA_VERSION}-jre |  |
| services/spring-boot/notification-service | Spring Boot | 4.0.1 | 25 | build=eclipse-temurin:${JAVA_VERSION}-jdk; runtime=eclipse-temurin:${JAVA_VERSION}-jre |  |
| services/spring-boot/analytics-service | Spring Boot | 4.0.1 | 25 | build=eclipse-temurin:${JAVA_VERSION}-jdk; runtime=eclipse-temurin:${JAVA_VERSION}-jre |  |
| services/spring-boot/gateway-service | Spring Boot | 4.0.1 | 25 | build=eclipse-temurin:${JAVA_VERSION}-jdk; runtime=eclipse-temurin:${JAVA_VERSION}-jre |  |
| services/quarkus/catalog-service | Quarkus | 3.15.0 | unknown | build=eclipse-temurin:${JAVA_VERSION}-jdk; runtime=eclipse-temurin:${JAVA_VERSION}-jre | java target unknown |

## main
| service path | framework | framework version | java target | docker base image | notes |
| --- | --- | --- | --- | --- | --- |
| services/spring-boot/orders-service | Spring Boot | 3.3.4 | 21 | build=maven:3.9.9-eclipse-temurin-21; runtime=eclipse-temurin:21-jre |  |
| services/spring-boot/billing-service | Spring Boot | 3.3.4 | 21 | build=maven:3.9.9-eclipse-temurin-21; runtime=eclipse-temurin:21-jre |  |
| services/spring-boot/notification-service | Spring Boot | 3.3.4 | 21 | build=maven:3.9.9-eclipse-temurin-21; runtime=eclipse-temurin:21-jre |  |
| services/spring-boot/analytics-service | Spring Boot | 3.3.4 | 21 | build=maven:3.9.9-eclipse-temurin-21; runtime=eclipse-temurin:21-jre |  |
| services/spring-boot/gateway-service | Spring Boot | 3.3.4 | 21 | build=maven:3.9.9-eclipse-temurin-21; runtime=eclipse-temurin:21-jre |  |
| services/quarkus/catalog-service | Quarkus | 3.15.0 | build=21; runtime=21 | build=maven:3.9.9-eclipse-temurin-21; runtime=eclipse-temurin:21-jre | java target derived from Dockerfile |

