#!/bin/sh

_=${BASE_DIR:=$(git rev-parse --show-toplevel)}

find_docker_images="$(dirname $0)/find_docker_images.sh"
_=${DOCKER_IMAGES:=$(${find_docker_images})}
echo ${DOCKER_IMAGES}
CURRENT_VERSION=$(git describe --tags --abbrev=0)

for IMAGE in ${DOCKER_IMAGES}; do
    DOCKERFILE_REVISION=$(git log -n 1 --pretty=format:%H -- ${IMAGE})
    DOCKER_ALREADY_BUILT=$(git tag ${CURRENT_VERSION} --contains ${DOCKERFILE_REVISION}|wc -l)
    if [ 0 -ne "${DOCKER_ALREADY_BUILT}" ]; then
        docker build ${BASE_DIR}/${IMAGE}
    fi
done
