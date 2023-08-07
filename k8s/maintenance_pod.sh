#!/bin/bash
set -eu
trap 'echo "pod setup failed" && exit 2' ERR

usage() { echo "Usage: $0 [-v <value>] <repo_name>"  1>&2; exit 1; }

append_values() {
    echo "${1}:" >> ${VALUES_FILE}
    yq -y ".${1}" $APP_VALUES_FILE | sed -e 's/^/  /' >> ${VALUES_FILE}
}

if [ $# -lt 1 ]; then
   usage
fi

HELM_VALUES=""
DEBUG=0
while getopts "dhv:" OPTION; do
    case "$OPTION" in
        v) HELM_VALUES="${HELM_VALUES},${OPTARG}";;
        d) DEBUG=1;;
        *) usage;;
    esac
done
shift $((OPTIND-1))

REPO_NAME=$1
shift


# Client Version: v1.27.4
KUBECTL_VERSION=$(kubectl version --short 2>/dev/null | grep 'Client Version: v' | sed 's/Client Version: v//')
if [ "$(echo -e "1.25\n$KUBECTL_VERSION" | sort -rV | head -n1)" = "1.25" ]; then 
  echo "$0 needs kubect version 1.25 or greater"
  exit 1
fi

# fetch APP name
APP_INSTANCE=prod
REPO_ORG=uw-it-aca
REPO_BRANCH=main
APP=$(curl -s https://raw.githubusercontent.com/${REPO_ORG}/${REPO_NAME}/${REPO_BRANCH}/docker/${APP_INSTANCE}-values.yml | yq -r '.repo')

# gather k8s context
APP_NAME=$(kubectl get deployment --no-headers -o custom-columns=":metadata.name" | grep -E "${APP}-prod-(test|prod)$")
APP_INSTANCE=$(echo $APP_NAME | sed "s/^${APP}-prod-//")
APP_IMAGE_TAG=$(kubectl get deployment -l app.kubernetes.io/name=$APP_NAME -o jsonpath='{.items[0].spec.template.spec.containers[0].image}' | sed 's/^.*[:]//')
WORKING_ID=${APP}-maintenance-${APP_INSTANCE}-${APP_IMAGE_TAG}

APP_HOME_DIR=$(echo ~/.k8s_maintenance)
WORKING_DIR=${APP_HOME_DIR}/${WORKING_ID}
VALUES_DIR=${WORKING_DIR}/values
LOGGING_DIR=${WORKING_DIR}/log
APP_VALUES_FILE=${VALUES_DIR}/${APP_INSTANCE}-values.yml
WORKING_VALUES_FILENAME=values.yml
VALUES_FILE=${VALUES_DIR}/${WORKING_VALUES_FILENAME}
WORKING_MANIFEST_FILE=${WORKING_DIR}/manifest.yml

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

# set up working directory
mkdir -p $APP_HOME_DIR $WORKING_DIR $VALUES_DIR $LOGGING_DIR

# fetch fresh copy of chart templates
rm -rf $CHART_DIR
git clone --depth 1 $CHART_REPO_PATH --branch $CHART_BRANCH $CHART_DIR &> $LOGGING_DIR/chart-clone.log

# fetch fresh app values file
curl -s https://raw.githubusercontent.com/${REPO_ORG}/${REPO_NAME}/${REPO_BRANCH}/docker/${APP_INSTANCE}-values.yml > $APP_VALUES_FILE

# initialize values file, disabling unnecessary components and k8s objects
cat <<EOF > ${VALUES_DIR}/${WORKING_VALUES_FILENAME}
repo: $APP
instance: maintenance
image:
  repository: IMAGE_REGISTRY
  tag: IMAGE_TAG
deployment:
  enabled: true
deploymentInitialization:
  enabled: false
service:
  enabled: false
lifecycle:
  enabled: false
autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 1
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
#append_values database
# append_values externalService
append_values certs
append_values environmentVariables
append_values environmentVariablesSecrets
#append_values externalSecrets

# dynamic deployment values
CHART_VERSION=$(cd ${CHART_DIR}; git rev-parse $CHART_BRANCH | cut -b 1-7)
IR_PARTS=(${REGISTRY_HOSTNAME}
          ${REGISTRY_PROJECT_ID}
          ${REGISTRY_PATH}
          ${APP})
OVERRIDE_VALUES="image.tag=${APP_IMAGE_TAG},chartVersion=${CHART_VERSION},image.repository=$(IFS=/; echo "${IR_PARTS[*]}"),${HELM_VALUES}"

if [ $DEBUG -eq 1 ]; then
    echo APP: $APP
    echo APP_NAME: $APP_NAME
    echo APP_INSTANCE: $APP_INSTANCE
    echo APP_IMAGE_TAG: $APP_IMAGE_TAG
    echo WORKING_ID: $WORKING_ID
    echo WORKING_DIR: $WORKING_DIR
    echo APP_VALUES_FILE: $APP_VALUES_FILE
    echo WORKING_VALUES_FILENAME: $WORKING_VALUES_FILENAME
    echo WORKING_MANIFEST_FILE: $WORKING_MANIFEST_FILE
    echo OVERRIDE_VALUES: $OVERRIDE_VALUES
fi

docker run -v ${CHART_DIR}:/chart -v ${VALUES_DIR}:/values \
       $HELM_IMAGE template ${APP}-maintenance /chart --set-string "$OVERRIDE_VALUES" \
       --debug -f /values/$WORKING_VALUES_FILENAME -f /dev/null |
    yq -y -e 'del(select(.kind == "ExternalSecret"))' |
    yq -y -e 'select(.kind == "Deployment").spec.template.spec.containers[0].command = ["/bin/sh", "-c", "while :; do sleep 30 ; done"]' \
       > $WORKING_MANIFEST_FILE

if [ $? -ne 0 ]; then
    echo helm fail
    exit 1
fi

if [ $DEBUG -eq 1 ]; then
    cat $WORKING_MANIFEST_FILE
fi

echo "To create maintenance pod: kubectl apply -f $WORKING_MANIFEST_FILE"

