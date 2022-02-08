#!/bin/bash

##
## A simple script to dump a 
##

if [[ $# < 3 ]]; then
    echo "usage: $0 <database_name> <database_instance>/<src_database_id> [<destination_database_instance>/]<destination_database_id>"
    exit 1
fi

IFS='/'

ARG=$(echo $1); shift
DATABASE_NAME=${ARG[0]}

ARG=$(echo $1); shift
DATABASE_INSTANCE=${ARG[0]}
SRC_DATABASE_INSTANCE=${ARG[0]}
SRC_DATABASE=${ARG[1]}

ARG=$(echo $2); shift
ARG_LEN=${#ARG[@]}
DST_DATABASE_INSTANCE=$((ARG_LEN == 2 ? ARG[0] : SRC_DATABASE_INSTANCE))
DST_DATABASE=$((ARG_LEN == 2 ? ARG[1] : ARG[2]))

BUCKET_NAME=${3:-"${DATABASE_NAME}-db-migration"}
SNAPSHOT_FILE="snapshot-${SRC_DATABASE}-$(date '+%Y-%m-%d').sql"
SNAPSHOT_TMPFILE="/tmp/$SHAPSHOT_FILE"
SNAPSHOT_URL="gs://${BUCKET_NAME}/$SNAPSHOT_FILE"

echo "Preparing to snapshot ${SRC_DATABASE_INSTANCE}/${SRC_DATABASE} to ${DST_DATABASE_INSTANCE}/${DST_DATABASE} ..."
exit

gcloud sql export sql ${SRC_DATABASE_INSTANCE} "${SNAPSHOT_URL}" --database=${SRC_DATABASE} --offload

gsutil cp "${SNAPSHOT_URL}" - | sed -e "s/^\(USE `${DATABASE_NAME}`;\)\$/-- \1/" -e 's/^\(CREATE .*;\)$/-- \1/' > $SNAPSHOT_TMPFILE

gcloud sql import sql ${DST_DATABASE_INSTANCE} "${SNAPSHOT_URL}" --database=${DST_DATABASE}
