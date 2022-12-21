#!/bin/bash

##
## A simple script to copy one gcp db to another.  Useful for copying a prod db snapshot to a test db.
##

if [[ $# < 4 ]]; then
    echo "usage: $0 <gcp_db_instance_id> <source_database_name> <destination_database_name> <gcp_bucket_for_copy>"
    exit 1
fi

DB_INSTANCE_ID=$(echo $1); shift
SOURCE_DB=$(echo $1); shift
DESTINATION_DB=$(echo $1); shift
GCP_BUCKET=$(echo $1); shift

DATESTAMP=$(date '+%Y-%m-%d')
EXPORT_BUCKET=gs://${GCP_BUCKET}/${SOURCE_DB}-db-export-${DATESTAMP}.sql
IMPORT_BUCKET=gs://${GCP_BUCKET}/${DESTINATION_DB}-db-test-import-${DATESTAMP}.sql
LOCAL_TMPFILE=/tmp/${SOURCE_DB}-db-clean.sql

proceed () {
    echo
    read -p "$1 (y/n)?" yn
    case $yn in
        [Yy]*);;
        *) echo "Aborting"; exit;;
    esac
    echo
}

proceed "Export database $SOURCE_DB on instance $DB_INSTANCE_ID to $EXPORT_BUCKET"
gcloud sql export sql $DB_INSTANCE_ID $EXPORT_BUCKET --database=$SOURCE_DB --offload

proceed "Sanitize exported sql in $EXPORT_BUCKET"
gsutil cp $EXPORT_BUCKET - | sed -e 's/^\(USE .*;\)$/-- \1/' -e 's/^\(CREATE .*;\)$/-- \1/' > $LOCAL_TMPFILE

echo head -30 $LOCAL_TMPFILE
proceed "Do USE and CREATE clauses look suitably commented?\n"

proceed "Upload sanitized sql to $IMPORT_BUCKET"
gsutil cp $LOCAL_TMPFILE $IMPORT_BUCKET
rm $LOCAL_TMPFILE

proceed "Import $IMPORT_BUCKET to $DESTINATION_DB in $DB_INSTANCE_ID"
gcloud sql import sql $DB_INSTANCE_ID $IMPORT_BUCKET --database=$DESTINATION_DB

proceed "Remove export and import buckets"
echo "Removing $IMPORT_BUCKET"
gsutil rm $IMPORT_BUCKET
echo "Removing $EXPORT_BUCKET"
gsutil rm $EXPORT_BUCKET
