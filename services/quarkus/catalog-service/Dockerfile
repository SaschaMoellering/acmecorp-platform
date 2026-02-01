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

COPY --from=build-aot /project/target /tmp/target
RUN set -euo pipefail; \
    for runner in /tmp/target/*/catalog-service-*-runner /tmp/target/catalog-service-*-runner; do \
      if [ -f "$runner" ]; then \
        cp "$runner" /catalog-service-runner; \
        rm -rf /tmp/target; \
        exit 0; \
      fi; \
    done; \
    echo "catalog-service native runner not found" >&2; \
    ls -la /tmp/target >&2 || true; \
    exit 1

USER 1000:1000

EXPOSE 8080

CMD ["./catalog-service-runner"]
