#!/bin/bash -ue

. ./VERSIONS

BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
VCS_REF=$(git rev-parse --verify HEAD)
VERSION=$(git describe --always --long --dirty --broken)

docker build \
        -t "zenko-zookeeper:${VERSION}" \
        --build-arg "ZOOKEEPER_IMAGE_SHA256=${ZOOKEEPER_IMAGE_SHA256}" \
        --build-arg "ZOOKEEPER_VERSION=${ZOOKEEPER_VERSION}" \
        --build-arg "PROMETHEUS_AGENT_VERSION=${PROMETHEUS_AGENT_VERSION}" \
        --build-arg "PROMETHEUS_AGENT_MD5SUM=${PROMETHEUS_AGENT_MD5SUM}" \
        --build-arg "BUILD_DATE=${BUILD_DATE}" \
        --build-arg "VCS_REF=${VCS_REF}" \
        --build-arg "VERSION=${VERSION}" \
        .

echo "Built zenko-zookeeper:${VERSION}"
