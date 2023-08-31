#!/bin/bash
set -eu
trap 'echo "pod setup failed" && exit 2' ERR

FORMAT_BOLD=$(tput bold)
FORMAT_NORMAL=$(tput sgr0)

USAGE_STRING="${0##*/} [-h] <repo_name> [-d] [ [-v <value>] create | delete | cp src_file dst_file | sh ]"

man_page() {
    cat <<EOF
${FORMAT_BOLD}NAME${FORMAT_NORMAL}
        ${0##*/} - manage and interact with a maintenance pod in kubernetes

${FORMAT_BOLD}SYNOPSIS${FORMAT_NORMAL}
        $USAGE_STRING


${FORMAT_BOLD}DESCRIPTION${FORMAT_NORMAL}
        The script ${0##*/} takes an application github repo name and
        creates a kubernetes maintenance pod in the current kubectl
        context.  The maintenance pod will have all of the environment,
        access and resources of an application pod.

        However, it is NOT part of the application's deployed service
        and does not receive page requests.

        The pod and associated deployment is created relative to:

             kubectl config current-context

        Optional settings are supported.

        ${FORMAT_BOLD}-d${FORMAT_NORMAL}
                increase debug output

        ${FORMAT_BOLD}-v var=value${FORMAT_NORMAL}
                for creation of maintenance pod, override values
                defined in applications values file. for example:

                    -v resources.limits.cpu=750m
                    -v resources.requests.memory=512Mi

        ${FORMAT_BOLD}create${FORMAT_NORMAL}
                references application's values file (based on the
                current kubernetes context) to create deployment
                of a single maintenance pod.

        ${FORMAT_BOLD}delete${FORMAT_NORMAL}
                remove the maintenance pod and its deployment from
                the cluster.

        ${FORMAT_BOLD}sh${FORMAT_NORMAL}
                start an interactive shell on the maintenance pod.

        ${FORMAT_BOLD}cp <src_file> <dst_file>${FORMAT_NORMAL}
                copy the source file from your workstation to the path
                and filename specified by the destination file.


EOF
}

raw_commands() {
    cat <<EOF
# To create maintenance pod:
kubectl apply -f $WORKING_MANIFEST_FILE

# To copy an updated settings file onto the pod:
    kubectl cp docker/settings.py \$(kubectl get pod | grep ${APP}-prod-maintenance | awk '{print \$1}'):/app/project/settings.py

# To exec a shell on the newly created pod:
kubectl exec -it \$(kubectl get pod | grep ${APP}-prod-maintenance | awk '{print \$1}') -- bash

# To remove the pod and it's deployment:
kubectl delete deployment ${APP}-prod-maintenance

EOF
}

usage() {
    echo "usage: $USAGE_STRING" 1>&2
    exit 1
}

debug() {
    if [ $DEBUG -gt 0 ]; then
        echo "$1" 1>&2
    fi
}

append_values() {
    echo "${1}:" >> ${VALUES_FILE}
    yq -y ".${1}" $APP_VALUES_FILE | sed -e 's/^/  /' >> ${VALUES_FILE}
}

deployment_running() {
    $(kubectl get deployment ${1}-prod-maintenance >/dev/null 2>&1)
    echo -n $?
}

maintenance_pod_name() {
    echo $(kubectl get pod -l app.kubernetes.io/name=${1}-prod-maintenance -o json | jq -r '.items[0].metadata.name | select( . != null )')
}

get_app_values() {
    TMP_VALUES=/tmp/maintenance-pod-app-values
    VALUES_RESPONSE=$(curl -o $TMP_VALUES -w "%{http_code}" -s https://raw.githubusercontent.com/${1}/${2}/${3}/docker/${4}-values.yml)

    if [ $VALUES_RESPONSE -ne 200 ]; then
        echo "problem fetching values from repo (${VALUES_RESPONSE}).  repo name \"${REPO_NAME}\" correct?"
        exit 1
    fi

    TMP_VALUES_ENV=$(cat $TMP_VALUES)
    rm $TMP_VALUES
    echo "$TMP_VALUES_ENV"
}

if [ $# -lt 1 ] || [ "$1" == "-h" ]; then
    man_page
    exit 1
fi

REPO_NAME=$1; shift

HELM_VALUES=""
DEBUG=0
while getopts "dhv:" OPTION; do
    case "$OPTION" in
        h) man_page; exit 0;;
        v) HELM_VALUES="${HELM_VALUES},${OPTARG}";;
        d) DEBUG=1;;
        *) usage;;
    esac
done
shift $((OPTIND-1))

# Client Version: v1.27.4
KUBECTL_VERSION=$(kubectl version --short 2>/dev/null | grep 'Client Version: v' | sed 's/Client Version: v//')
if [ "$(echo -e "1.25\n$KUBECTL_VERSION" | sort -rV | head -n1)" = "1.25" ]; then
  echo "$0 needs kubect version 1.25 or greater"
  exit 1
fi

debug "fetch prod values to determine app name (.repo value)"
APP_INSTANCE=prod
REPO_ORG=uw-it-aca
REPO_BRANCH=main
APP_VALUES=$(get_app_values $REPO_ORG $REPO_NAME $REPO_BRANCH $APP_INSTANCE)

APP=$(echo "$APP_VALUES" | yq -r '.repo' -)

APP_NAME=$(kubectl get deployment --no-headers -o custom-columns=":metadata.name" | grep -E "${APP}-prod-(test|prod)$")
debug "identified k8s app deployment ${APP_NAME}"

APP_INSTANCE=$(echo $APP_NAME | sed "s/^${APP}-prod-//")
APP_IMAGE_TAG=$(kubectl get deployment -l app.kubernetes.io/name=$APP_NAME -o jsonpath='{.items[0].spec.template.spec.containers[0].image}' | sed 's/^.*[:]//')
WORKING_ID=${APP}-maintenance-${APP_INSTANCE}-${APP_IMAGE_TAG}
debug "WORKING_ID=$WORKING_ID"

APP_HOME_DIR=$(echo ~/.k8s_maintenance)
WORKING_DIR=${APP_HOME_DIR}/${WORKING_ID}
VALUES_DIR=${WORKING_DIR}/values
LOGGING_DIR=${WORKING_DIR}/log
APP_VALUES_FILE=${VALUES_DIR}/${APP_INSTANCE}-values.yml
WORKING_VALUES_FILENAME=values.yml
VALUES_FILE=${VALUES_DIR}/${WORKING_VALUES_FILENAME}
WORKING_MANIFEST_FILE=${WORKING_DIR}/manifest.yml
debug "working directory $WORKING_DIR"
debug "maintenance manifest in $WORKING_MANIFEST_FILE"

HELM_APP_VERSION="3.4.2"
HELM_CHART_BRANCH="${HELM_CHART_BRANCH=master}"
HELM_IMAGE="alpine/helm:${HELM_APP_VERSION}"

CHART_NAME=django-production-chart
CHART_BRANCH=main
CHART_REPO_PATH="https://github.com/${REPO_ORG}/${CHART_NAME}.git"
CHART_DIR=${APP_HOME_DIR}/chart

REGISTRY_HOSTNAME=us-docker.pkg.dev
REGISTRY_PROJECT_ID=uwit-mci-axdd
REGISTRY_PATH=containers

debug "set up working directories"
mkdir -p $APP_HOME_DIR $WORKING_DIR $VALUES_DIR $LOGGING_DIR

debug "fetch charts $CHART_REPO_PATH to $CHART_DIR"
rm -rf $CHART_DIR
git clone --depth 1 $CHART_REPO_PATH --branch $CHART_BRANCH $CHART_DIR &> $LOGGING_DIR/chart-clone.log

debug "fetch app ${APP_INSTANCE}-values.yml values to $APP_VALUES_FILE"
echo "$(get_app_values $REPO_ORG $REPO_NAME $REPO_BRANCH $APP_INSTANCE)" > $APP_VALUES_FILE

debug "initialize maintenance deployment values, disabling unnecessary components and k8s objects"
cat <<EOF > ${VALUES_DIR}/${WORKING_VALUES_FILENAME}
repo: $APP
instance: maintenance
image:
  repository: IMAGE_REGISTRY
  tag: IMAGE_TAG
autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 1
deployment:
  enabled: true
deploymentInitialization:
  enabled: false
service:
  enabled: false
lifecycle:
  enabled: false
metrics:
  enabled: false
securityPolicy:
  enabled: false
readiness:
  enabled: false
memcached:
  enabled: false
cronjob:
  enabled: false
daemon:
  enabled: false
EOF

# copy app values necessary for maintenance pod:
append_values database
append_values certs
append_values environmentVariables
append_values environmentVariablesSecrets

CHART_VERSION=$(cd ${CHART_DIR}; git rev-parse $CHART_BRANCH | cut -b 1-7)
IR_PARTS=(${REGISTRY_HOSTNAME}
          ${REGISTRY_PROJECT_ID}
          ${REGISTRY_PATH}
          ${APP})
OVERRIDE_VALUES="image.tag=${APP_IMAGE_TAG},chartVersion=${CHART_VERSION},image.repository=$(IFS=/; echo "${IR_PARTS[*]}"),${HELM_VALUES}"
debug "dynamic deployment values: $OVERRIDE_VALUES"

#if [ $DEBUG -gt 0 ]; then
#    IFS= read -r -d '' VAR_LIST <<EOF
#APP: $APP
#APP_NAME: $APP_NAME
#APP_INSTANCE: $APP_INSTANCE
#APP_IMAGE_TAG: $APP_IMAGE_TAG
#WORKING_ID: $WORKING_ID
#WORKING_DIR: $WORKING_DIR
#APP_VALUES_FILE: $APP_VALUES_FILE
#WORKING_VALUES_FILENAME: $WORKING_VALUES_FILENAME
#WORKING_MANIFEST_FILE: $WORKING_MANIFEST_FILE
#OVERRIDE_VALUES: $OVERRIDE_VALUES
#EOF
#    debug "$VAR_LIST"
#fi

debug "run heml docker image to build manifest $WORKING_MANIFEST_FILE"
docker run -v ${CHART_DIR}:/chart -v ${VALUES_DIR}:/values \
       $HELM_IMAGE template ${APP}-maintenance /chart --set-string "$OVERRIDE_VALUES" \
       -f /values/$WORKING_VALUES_FILENAME -f /dev/null > $WORKING_MANIFEST_FILE

if [ $? -ne 0 ]; then
    echo helm fail
    exit 1
fi

debug "override default container command"
TMP_MANIFEST=/tmp/tmp-values.yaml
sed -e '/ports:$/i \          command: ["/bin/bash", "-c", "tail -f /dev/null"]' $WORKING_MANIFEST_FILE > $TMP_MANIFEST
sed -e '/ports:/,+3d' $TMP_MANIFEST > $WORKING_MANIFEST_FILE
rm $TMP_MANIFEST

if [ $# -gt 0 ]; then
    ACTION=$1 ; shift
    case "$ACTION" in
        create)
            if [ "$(deployment_running $APP)" == "0" ]; then
                echo "deployment ${APP}-prod-maintenance already running"
                exit 1
            fi

            echo -n "Applying deployment ${APP}-prod-maintenance"
            kubectl apply -f $WORKING_MANIFEST_FILE 2>&1 >${LOGGING_DIR}/deployment.log
            RUNNING_POD=""
            while [ -z "$RUNNING_POD" ]; do
                echo -n '.'
                sleep 3s
                RUNNING_POD=$(maintenance_pod_name $APP)
            done
            echo

            exit 0
            ;;
        delete)
            if [ "$(deployment_running $APP)" == "1" ]; then
                echo "deployment ${APP}-prod-maintenance is not running"
                exit 1
            fi

            echo "deleting deployment ${APP}-prod-maintenance"
            kubectl delete deployment ${APP}-prod-maintenance
            exit 0
            ;;
        cp)
            if [ $# -lt 2 ]; then
                usage
            fi

            SRCFILE=$1 ; shift
            DSTFILE=$1 ; shift

            POD_NAME=$(maintenance_pod_name $APP)
            if [ -z "$POD_NAME" ]; then
                echo "maintenence pod is not running"
                exit 1
            fi

            kubectl cp $SRCFILE ${POD_NAME}:${DSTFILE}
            exit 0
            ;;
        sh)
            POD_NAME=$(maintenance_pod_name $APP)
            if [ -z "$POD_NAME" ]; then
                echo "maintenence pod is not running"
                exit 1
            fi

            kubectl exec -it ${POD_NAME} -- bash
            exit 0
            ;;
        *)
            usage
            ;;
    esac
else
    raw_commands
fi
