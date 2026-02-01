FROM quay.io/quarkus/ubi-quarkus-mandrel-builder-image:jdk-21 AS build-aot

USER root
RUN microdnf install -y unzip zip

USER 1001
RUN     curl -s "https://get.sdkman.io" | bash;     bash -c "source $HOME/.sdkman/bin/sdkman-init.sh;     sdk install maven;"

WORKDIR /project

COPY ./pom.xml ./pom.xml
COPY src ./src/

ENV MAVEN_OPTS='-Xmx8g'
RUN bash -c "source $HOME/.sdkman/bin/sdkman-init.sh && mvn -Dmaven.test.skip=true clean package -Pnative"

FROM public.ecr.aws/amazonlinux/amazonlinux:2023
RUN yum install -y shadow-utils

RUN groupadd --system spring -g 1000
RUN adduser spring -u 1000 -g 1000

COPY --from=build-aot /project/target/gateway-service /

USER 1000:1000

EXPOSE 8080

CMD ["./gateway-service", "-Dserver.port=8080"]
