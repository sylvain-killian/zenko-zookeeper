# Host of the Zookeeper service, defaults to 'localhost'
ZOOKEEPER_HOST=${ZOOKEEPER_HOST:-localhost}
# Port of the Zookeeper service, defaults to 2181
ZOOKEEPER_PORT=${ZOOKEEPER_PORT:-2181}
# Mode of the ensemble: 'standalone' or 'replicated'
ZOOKEEPER_MODE=${ZOOKEEPER_MODE:-}

# Host of the Prometheus JMX Agent, defaults to 'localhost'
PROMETHEUS_AGENT_HOST=${PROMETHEUS_AGENT_HOST:-localhost}
# Port of the Prometheus JMX Agent, defaults to 9141
PROMETHEUS_AGENT_PORT=${PROMETHEUS_AGENT_PORT:-9141}

test_zkcli_ls_root() {
        assert "zkCli.sh -server ${ZOOKEEPER_HOST}:${ZOOKEEPER_PORT} ls /"
}

test_zookeeper_stat_mode() {
        mode=$(echo stat | nc "${ZOOKEEPER_HOST}" "${ZOOKEEPER_PORT}" | grep "^Mode: " | awk '{ print $2 }')
        assert_not_equals "" "${mode}"

	case "${ZOOKEEPER_MODE}" in
		standalone)
			assert "[[ \"${mode}\" = standalone ]]" \
                                "Mode is '${mode}', expected 'standalone'"
			;;
		replicated)
			assert "[[ \"${mode}\" =~ ^(leader|follower) ]]" \
                                "Mode is '${mode}', expected one of 'leader', 'follower'"
			;;
		*)
			fail "Unknown ZOOKEEPER_MODE: '${ZOOKEEPER_MODE}'"
			;;
	esac
}

test_prometheus_agent_zookeeper() {
        assert "wget --timeout=10 -q -O - \"${PROMETHEUS_AGENT_HOST}:${PROMETHEUS_AGENT_PORT}\" | grep zookeeper > /dev/null" \
                "'zookeeper' not found in Prometheus metrics"
}
