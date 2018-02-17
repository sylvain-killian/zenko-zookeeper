#!/bin/bash

set -eu

ZOO_HEAP_SIZE=${ZOO_HEAP_SIZE:-2G}
ZOO_SERVER_PORT=2888
ZOO_ELECTION_PORT=3888

die() {
        echo "$*" 1>&2
        exit 1
}

test -n "${PROMETHEUS_AGENT_JAR:-}" || die "Missing PROMETHEUS_AGENT_JAR"
test -n "${PROMETHEUS_AGENT_CONFIG:-}" || die "Missing PROMETHEUS_AGENT_CONFIG"
PROMETHEUS_AGENT_PORT=${PROMETHEUS_AGENT_PORT:-9141}

HOST=$(hostname -s)
DOMAIN=$(hostname -d)

function find_node_id() {
    echo "Find current node Id"

    if [[ $HOST =~ (.*)-([0-9]+)$ ]]; then
        NAME=${BASH_REMATCH[1]}
        ORD=${BASH_REMATCH[2]}
    else
        die "Failed to extract ordinal from hostname $HOST"
    fi
    export ZOO_MY_ID=$((ORD+1))
}

function compute_server_list() {
    if [ -z $ZOO_REPLICAS ]; then
        die "ZOO_REPLICAS is a mandatory environment variable"
    fi
    local ZOO_SERVERS
    ZOO_SERVERS=""
    for (( i=1; i<=$ZOO_REPLICAS; i++ ))
    do
        ZOO_SERVERS="$ZOO_SERVERS server.$i=$NAME-$((i-1)).$DOMAIN:$ZOO_SERVER_PORT:$ZOO_ELECTION_PORT"
    done
    echo $ZOO_SERVERS
    export ZOO_SERVERS=$ZOO_SERVERS
}

function create_java_env() {
    echo "Creating JVM configuration file"
    JAVA_ENV_FILE=$ZOO_CONF_DIR/java.env
    cat > $JAVA_ENV_FILE << EOF
# SERVER_JVMFLAGS only: no need to have a huge heap for zkCli, and loading the
# Prometheus agent on the same port would make it go nuts.
SERVER_JVMFLAGS="-Xmx$ZOO_HEAP_SIZE -Xms$ZOO_HEAP_SIZE"
SERVER_JVMFLAGS="\${SERVER_JVMFLAGS} -javaagent:${PROMETHEUS_AGENT_JAR}=${PROMETHEUS_AGENT_PORT}:${PROMETHEUS_AGENT_CONFIG}"
EOF
    # echo "ZOO_LOG_DIR=$ZOO_LOG_DIR" >> $JAVA_ENV_FILE
    echo "Wrote JVM configuration to $JAVA_ENV_FILE"
}

find_node_id && compute_server_list && create_java_env

exec /docker-entrypoint.sh "$@"
