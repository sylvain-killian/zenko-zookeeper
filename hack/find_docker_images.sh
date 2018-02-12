#!/bin/sh

IMAGE_DIR='images'

_=${BASE_DIR:=$(git rev-parse --show-toplevel)}

DOCKERFILES=$(find "${BASE_DIR}/${IMAGE_DIR}" -name 'Dockerfile')
DOCKER_IMAGES=""
for DOCKERFILE_DIR in ${DOCKERFILES}; do
    IMAGE=$(realpath --relative-base=${BASE_DIR} $(dirname ${DOCKERFILE_DIR}))
    echo ${IMAGE}
done;
