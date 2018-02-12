#!/bin/sh -ue

. ./VERSIONS

BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
VCS_REF=$(git rev-parse --verify HEAD)
VCS_VERSION=$(git describe --tags --dirty)
_=${DOCKER_REGISTRY:=${DOCKER_REGISTRY}}
_=${DOCKER_TAG:=${VCS_VERSION#"v"}}

DOCKER_NAME="${DOCKER_REGISTRY}zenko-zookeeper:${DOCKER_TAG}"

docker build \
        -t "${DOCKER_NAME}" \
        --build-arg "ZOOKEEPER_IMAGE_SHA256=${ZOOKEEPER_IMAGE_SHA256}" \
        --build-arg "ZOOKEEPER_VERSION=${ZOOKEEPER_VERSION}" \
        --build-arg "PROMETHEUS_AGENT_VERSION=${PROMETHEUS_AGENT_VERSION}" \
        --build-arg "PROMETHEUS_AGENT_MD5SUM=${PROMETHEUS_AGENT_MD5SUM}" \
        --build-arg "BUILD_DATE=${BUILD_DATE}" \
        --build-arg "VCS_REF=${VCS_REF}" \
        --build-arg "VERSION=${DOCKER_TAG}" \
        .

echo "Built ${DOCKER_NAME}"
