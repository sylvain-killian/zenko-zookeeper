# SHA256 digest of the base image
ARG ZOOKEEPER_IMAGE_SHA256
ARG ZOOKEEPER_IMAGE=docker.io/zookeeper

FROM $ZOOKEEPER_IMAGE@sha256:$ZOOKEEPER_IMAGE_SHA256

# Zookeeper version of the base image (contained in
# $ZOOKEEPER_IMAGE@sha256:$ZOOKEEPER_IMAGE_SHA256)
ARG ZOOKEEPER_VERSION

# Version of the Prometheus JMX Agent
ARG PROMETHEUS_AGENT_VERSION
# MD5 checksum of the Prometheus JMX Agent Jar
ARG PROMETHEUS_AGENT_MD5SUM
# URL of the Prometheus JMX Agent Jar
ARG PROMETHEUS_AGENT_URL=https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/$PROMETHEUS_AGENT_VERSION/jmx_prometheus_javaagent-$PROMETHEUS_AGENT_VERSION.jar

# Timestamp of the build, formatted as RFC3339
ARG BUILD_DATE
# Git revision of the tree at build time
ARG VCS_REF
# Version of the project, e.g. `git describe --always --long --dirty --broken`
ARG VERSION

ENV PROMETHEUS_AGENT_JAR=/opt/jmx_prometheus_javaagent/jmx_prometheus_javaagent-${PROMETHEUS_AGENT_VERSION}.jar
ENV PROMETHEUS_AGENT_CONFIG=/etc/prometheus_agent.yml
ENV PROMETHEUS_AGENT_PORT=9141

# Define here so it can be set as a label
ENV ZOO_HEAP_SIZE=2G
ENV ZOO_PORT=2181

EXPOSE $PROMETHEUS_AGENT_PORT

COPY zkOk.sh zkMetrics.sh /usr/local/bin/
COPY prometheus_agent.yml $PROMETHEUS_AGENT_CONFIG
COPY kubernetes-entrypoint.sh /
COPY tests.sh /

ENTRYPOINT ["/kubernetes-entrypoint.sh"]
# CMD is not inherited from the base image
CMD ["zkServer.sh", "start-foreground"]

# These contain BUILD_DATE so should come 'late' for layer caching
LABEL maintainer="zenko-platform@scality.com" \
      # http://label-schema.org/rc1/
      org.label-schema.build-date="$BUILD_DATE" \
      org.label-schema.name="zenko-zookeeper" \
      org.label-schema.description="Apache Zookeeper with integrated Prometheus exporter" \
      org.label-schema.url="https://scality.github.com/zenko-zookeeper" \
      org.label-schema.vcs-url="https://github.com/Scality/zenko-zookeeper" \
      org.label-schema.vcs-ref="$VCS_REF" \
      org.label-schema.vendor="Scality" \
      org.label-schema.version="$VERSION" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.docker.cmd="docker run -p $ZOO_PORT:$ZOO_PORT -p $PROMETHEUS_AGENT_PORT:$PROMETHEUS_AGENT_PORT -h zookeeper-0 -e ZOO_REPLICAS=1 zenko/zenko-zookeeper" \
      org.label-schema.docker.cmd.debug="docker exec -it \$CONTAINER zkCli.sh" \
      org.label-schema.docker.cmd.test="docker exec -it \$CONTAINER env ZOOKEEPER_MODE='standalone' bash_unit /tests.sh" \
      org.label-schema.docker.params="PROMETHEUS_AGENT_PORT=port of Prometheus exporter,ZOO_REPLICAS=number of Zookeeper replicas in the ensemble" \
      # https://github.com/opencontainers/image-spec/blob/master/annotations.md
      org.opencontainers.image.created="$BUILD_DATE" \
      org.opencontainers.image.authors="zenko-platform@scality.com" \
      org.opencontainers.image.url="https://scality.github.com/zenko-zookeeper" \
      org.opencontainers.image.source="https://github.com/Scality/zenko-zookeeper" \
      org.opencontainers.image.version="$VERSION" \
      org.opencontainers.image.revision="$VCS_REF" \
      org.opencontainers.image.vendor="Scality" \
      org.opencontainers.image.title="zenko-zookeeper" \
      org.opencontainers.image.description="Apache Zookeeper with integrated Prometheus exporter" \
      # https://docs.openshift.org/latest/creating_images/metadata.html
      io.openshift.tags="zenko,zookeeper,prometheus" \
      io.k8s.description="Apache Zookeeper with integrated Prometheus exporter" \
      io.openshift.non-scalable="true" \
      io.openshift.expose-services="$ZOO_PORT:zookeeper-client,2888:zookeeper-server,3888:zookeeper-election,$PROMETHEUS_AGENT_PORT:prometheus-agent" \
      io.openshift.min-memory="$ZOO_HEAP_SIZE" \
      # Various
      com.scality.zenko.zookeeper.version="$ZOOKEEPER_VERSION" \
      com.scality.zenko.prometheus_agent.version="$PROMETHEUS_AGENT_VERSION"

# RUN always creates a layer. Keeping it late in the game reduces the number of
# useless intermediate layers, in this case.
RUN set -x -o pipefail \
    && mkdir -p $(dirname "${PROMETHEUS_AGENT_JAR}") \
    && wget -q -O "${PROMETHEUS_AGENT_JAR}" "${PROMETHEUS_AGENT_URL}" \
    && echo "${PROMETHEUS_AGENT_MD5SUM}  ${PROMETHEUS_AGENT_JAR}" | md5sum -c \
    && wget -q -O /usr/local/bin/bash_unit https://raw.githubusercontent.com/pgrange/bash_unit/v1.6.1/bash_unit \
    && echo "6dc5d33e0838251f5f7d3c524572b4c5  /usr/local/bin/bash_unit" | md5sum -c \
    && chmod a+x /usr/local/bin/bash_unit
