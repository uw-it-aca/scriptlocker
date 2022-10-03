#!/bin/bash

if [ $# -ne 2 ]; then
    echo "usage: $(basename $0) <app_instance> <cron_job>"
    exit 1
fi

APP_INSTANCE=$1; shift
CRON_JOB=$1; shift

if [ -z "$PUSHGATEWAY" ]; then
    echo 'Environment variable missing: $PUSHGATEWAY'
    exit 1
fi

PUSHGATEWAY_PATH="metrics/job/${CRON_JOB}/instance/${APP_INSTANCE}"
cat <<EOF | curl --silent --show-error --data-binary @- "http://${PUSHGATEWAY}:9091/${PUSHGATEWAY_PATH}"
# HELP management_command_exit Management command exit code.
# TYPE management_command_exit gauge
management_command_exit{job="${CRON_JOB}",instance="${APP_INSTANCE}"} 0
EOF
