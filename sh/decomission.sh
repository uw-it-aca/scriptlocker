#!/bin/bash
set -e

##
## A script to decomission AXDD apps running in MCI
##
## usage: decommision <helm-values-file>
##

function setup_environment () {
  if [ -z "$1" ]; then
    echo "usage: $0 <helm-values-file>"
    exit 1
  else
    VALUES_FILE=$1
    VALUES_FILE_BASE=$(basename $1)
    APP_INSTANCE=$(echo $VALUES_FILE_BASE | sed -E 's/(test|prod)-values.y[a]?ml/\1/g')
    RELEASE_NAME=$(yq '.repo' $VALUES_FILE | sed -e 's/^"//' -e 's/"$//')-prod-${APP_INSTANCE}
    if [ "$APP_INSTANCE" = "prod" ]; then
      GCP_PROJECT="0011"
    elif [ "$APP_INSTANCE" = "test" ]; then
      GCP_PROJECT="0010"
    else
      echo "Cannot map values file ${APP_INSTANCE} to GCP project"
      exit 1
    fi
  
    APP_INSTANCE_CLUSTER="gke_uwit-mci-${GCP_PROJECT}_us-west1_uwit-mci-${GCP_PROJECT}-cluster"
    CURRENT_CLUSTER=$(/usr/bin/kubectl config current-context)
    if [ "$APP_INSTANCE_CLUSTER" != "$CURRENT_CLUSTER" ]; then
      echo "#"
      echo "# Switch to the $APP_INSTANCE cluster ($GCP_PROJECT) and re-run scipt."
      echo "#"
      echo "#   /usr/bin/kubectl config use-context $APP_INSTANCE_CLUSTER"
      echo "#"
      exit 1
    fi

    RELEASE_LABEL="app.kubernetes.io/instance=${RELEASE_NAME}"
    RELEASE_NAMESPACE="default"
  fi
}


function resource_cleanup () {
  echo "# ---"
  echo "# The following commands will remove cluster resources:"
  echo "#"
  for API in $(kubectl api-resources --verbs=delete --namespaced -o name); do
    OBJECTS=$(kubectl get --show-kind --ignore-not-found -l ${RELEASE_LABEL} -n $RELEASE_NAMESPACE $API 2> /dev/null)
    if [ -n "$OBJECTS" ]; then
      # echo "echo \"cleaning up $API\""
      while IFS= read -r line; do
        OBJECT_NAME=$(echo $line | awk '{print $1}')
        if [[ "$OBJECT_NAME" == *"/"* ]]; then
          echo "kubectl delete $(dirname $OBJECT_NAME) $(basename $OBJECT_NAME)"
        fi
      done <<< "$OBJECTS"
    fi
  done
}

function ingress_cleanup () {
# pick out ingress and warn to FIX DNS because it will soon vanish
# (provide instructions and link to <https://networks.uw.edu/networks/dns/resources>
  echo "# ---"
  echo "# DNS names found in ingress definition.  May need to do some manual"
  echo "# cleanup on <https://networks.uw.edu>.  Hostnames are:"
  echo "#"
  while IFS= read -r line; do
    ingress=$(echo $line | sed -e 's/^"//' -e 's/"$//')
    hostname=$(yq .ingress.hosts.\"${ingress}\".host $VALUES_FILE | sed -e 's/^"//' -e 's/"$'//)
    echo "#        $hostname        (defined in ${ingress})"
  done <<< "$(yq '.ingress.hosts | keys[]' $VALUES_FILE)"
  echo "#"
}

function database_cleanup () {
# pick out db names and warn that they may need to be decommissioned separately
# and provide instructions fo removal
  database=$(yq .database.name $VALUES_FILE | sed -e 's/^"//' -e 's/"$'//)
  engine=$(yq .database.engine $VALUES_FILE | sed -e 's/^"//' -e 's/"$'//)
  if [ -n "$database" ]; then
    echo "# ---"
    echo "# Databases to clean up include:"
    echo "#"
    echo "#        ${database}    (${engine})"
    echo "#"
  fi
}

function secrets_cleanup () {
# pick out vault paths and provide instructions for removal
  external_secrets=$(yq '.externalSecrets.secrets[] | .externalKey' $VALUES_FILE)
  if [ -n "$external_secrets" ]; then
    echo "# ---"
    echo "# There may also be some secrets to mop up:"
    echo "#"
    while IFS= read -r line; do
      secret_path=$(echo $line | sed -e 's/^"//' -e 's/"$//')
      echo "#        $secret_path"
      if [[ $secret_path == "axdd/kv/data/"* ]]; then
        url="https://mosler.s.uw.edu/ui/vault/secrets/axdd%2Fkv/show/$(echo $secret_path | sed -e 's.axdd/kv/data/..')"
        echo "#            $url"
        echo "#"
      fi
    done <<< "$external_secrets"
    echo "#"
  fi
}

function registry_cleanup () {
# pick out registry and explain how to clean up
  repo=$(yq .image.repository $VALUES_FILE | sed -e 's/^"//' -e 's/"$'//)
  if [ -n "$repo" ]; then
    echo "# ---"
    echo "# Be sure to cleanup associated image registries:"
    echo "#"
    echo "#        ${repo}"
    if [[ $repo == "gcr.io/uwit-mci-axdd/"* ]]; then
      gcp_repo=$(echo $repo | sed ":s:gcr.io/uwit-mci-axdd/:")
    fi
    echo "#            https://console.cloud.google.com/gcr/images/uwit-mci-axdd/global/${gcp_repo}?project=uwit-mci-axdd"
    echo "#"
  fi
}


function disable_github_workflow () {
  WORKFLOW_DIR=".github/workflows/"
  if [[ -d $WORKFLOW_DIR ]]; then
    echo "# ---"
    echo "# Disable the github workflows in $WORKFLOW_DIR."
    echo "#"
    while IFS= read -r line; do
      workflow=$(echo $line | sed -e 's/^"//' -e 's/"$//')
      echo "#     edit $workflow and rename the \"on:\" trigger to \"neveron:\""
      echo "#"
    done <<< "$(echo .github/workflows/*)"
  fi
}


function archive_repository () {
  echo "# ---"
  echo "# You probably want to archive the application's repository at:"
  echo "#"
  url=$(git config --get remote.origin.url | sed -e 's,git@github.com:,https://github.com/,' | sed -e 's,\.git$,/settings,')
  echo "#        $url"
  echo "#"
}


# Run through steps to decommision an AXD3 application

setup_environment $@

echo "#"
echo "# What follows is a report containing the steps necesaary"
echo "# to decommision the application $RELEASE_NAME based on the"
echo "# helm values provided in $VALUES_FILE_BASE"
echo "#"
echo "# NOTE: This is only a report."
echo "#       Nothing is modified by running this script."
echo "#       No objects or services are stopped or deleted."
echo "#"
echo "# NOTE ALSO: However, piping the output of this script"
echo "#            into bash will result in the deletion of"
echo "#            ALL kubernetes resources associated $RELEASE_NAME."
echo "#"

resource_cleanup
ingress_cleanup
database_cleanup
secrets_cleanup
registry_cleanup
disable_github_workflow
archive_repository
