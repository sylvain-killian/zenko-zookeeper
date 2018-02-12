#!/bin/sh

_=${BASE_DIR:=$(git rev-parse --show-toplevel)}
BUILD_DIR=${BASE_DIR}/build
ENV_FILE=${BUILD_DIR}/env.sh
_=${CURRENT_VERSION:=$(git describe --abbrev=0)}
_=${NEW_VERSION:=$(semver "${CURRENT_VERSION}" -i patch)}

echo ${NEW_VERSION}
mkdir -p "${BUILD_DIR}"
(
    echo $(declare -p BASE_DIR)
    echo $(declare -p CURRENT_VERSION)
    echo $(declare -p NEW_VERSION)
) > ${ENV_FILE}

cat "${ENV_FILE}"
