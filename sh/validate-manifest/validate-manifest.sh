#!/bin/bash
set -eu
trap 'echo $(Emphasize red "app deploy failed") && exit 2' ERR

# default configuration
INSTANCE="test"
HELM_CHART_BRANCH=""
HELM_APP_TAG="3.15.4"

Help()
{
    # Display Help
    echo "Validate generated k8s manifest and validate it from supplied helm values."
    echo
    echo "Syntax: scriptTemplate [-h|b|i]"
    echo "options:"
    echo "h     Print this Help."
    echo "b     Helm chart repository branch (default is local path ../django-production-chart)."
    echo "i     Generated template application instance (default: ${INSTANCE})."
    echo "t     Helm chart application container tag (default: ${HELM_APP_TAG})."
    echo
}

Emphasize()
{
    green="\e[32m"
    yellow="\e[33m"
    red="\e[31m"
    normal="\e[0m"

    color=$yellow
    if [ $# -gt 1 ]; then
        color=${!1}
        shift
    fi

    echo -e "${color}$1${normal}"
}

while getopts ":hb:i:" opt; do
  case $opt in
    h)
        Help
        exit;;
    b) HELM_CHART_BRANCH="$OPTARG"
        ;;
    i) INSTANCE="$OPTARG"
        ;;
    t) HELM_APP_TAG="$OPTARG"
        ;;
    \?) echo "Invalid option -$OPTARG" >&2
       exit 1;;
  esac
done

HELM_CHART_AUTHORITY="https://github.com/uw-it-aca/"
HELM_CHART_REPOSITORY="django-production-chart"
HELM_CHART_PATH=$(realpath "${PWD}/../${HELM_CHART_REPOSITORY}")

HELM_APP_IMAGE="alpine/helm:${HELM_APP_TAG}"

KUBECONFORM_IMAGE=ghcr.io/yannh/kubeconform
KUBECONFORM_VERSION=latest
KUBECONFORM_SCHEMA_URL=https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/
KUBECONFORM_SKIP_KINDS=ExternalSecret,ServiceMonitor

CHART_VALUES_DIR="${PWD}/docker"
CHART_VALUES_FILE="${INSTANCE}-values.yml"

CHECKOV_IMAGE=bridgecrew/checkov:latest
# aceptable policy overrides
#    CKV_K8S_21 - avoid default namespace
#    CKV_K8S_35 - secret files preferred over environment
#    CKV_K8S_43 - image reference by digest
#    CKV_K8S_106 - terminated-pod-gc-threshold set by MCI
#    CKV_K8S_107 - k8s profiling
CHECKOV_SKIP_CHECKS=CKV_K8S_21,CKV_K8S_35,CKV_K8S_43,CKV_K8S_106,CKV_K8S_107,CKV2_K8S_6

APP=$(basename $PWD)
MANIFEST_DIR=/tmp
MANIFEST_FILE=${APP}.yml
MANIFEST_PATH=${MANIFEST_DIR}/${MANIFEST_FILE}
KUBEVAL_OUTPUT=/tmp/kubeval-${APP}.out
CHECKOV_OUTPUT=/tmp/checkov-${APP}.out

OVERRIDE_VALUES="image.tag=123123123,xchartVersion=abc123"
if [ $# -gt 1 ]; then
    OVERRIDE_VALUES="${OVERRIDE_VALUES},image.repository=$2"
fi

if  [ ! -d ${HELM_CHART_PATH} ] || [ -n "$HELM_CHART_BRANCH" ];  then
    HELM_CHART_REPO="${HELM_CHART_AUTHORITY}${HELM_CHART_REPOSITORY}"
    HELM_CHART_PATH=/tmp/${HELM_CHART_REPOSITORY}

    if [ -d ${HELM_CHART_PATH} ]; then
        if [ -n "$( ls -A ${HELM_CHART_PATH} )" ]; then
            echo "removing existing helm chart path $(Emphasize $HELM_CHART_PATH)"
            rm -rf ${HELM_CHART_PATH}
        fi
    fi

    mkdir -p ${HELM_CHART_PATH}

    BRANCH_OPT=""
    if [ -n "$HELM_CHART_BRANCH" ]; then
        BRANCH_OPT="-b ${HELM_CHART_BRANCH}"
    fi

    echo "cloning helm chart repository $(Emphasize ${HELM_CHART_REPO}.git)"
    git clone $BRANCH_OPT --single-branch ${HELM_CHART_REPO}.git $HELM_CHART_PATH
else
    echo "using existing helm chart path $(Emphasize $HELM_CHART_PATH)"
fi


echo "using helm chart path $(Emphasize $HELM_CHART_PATH) with values $(Emphasize ${CHART_VALUES_DIR}/${CHART_VALUES_FILE})"
docker run -v ${HELM_CHART_PATH}:/chart -v ${CHART_VALUES_DIR}:/chart/values $HELM_APP_IMAGE template $APP /chart --set-string "$OVERRIDE_VALUES" --debug -f /chart/values/${CHART_VALUES_FILE} -f /dev/null > $MANIFEST_PATH
if [ $? -ne 0 ]; then
    echo helm fail
    exit 1
fi

echo "check for underscores"
if cat ${MANIFEST_PATH} | yq .metadata.name | grep '_'; then
    (echo "^^^ should replace underscores with dashes" && exit 1)
fi

#echo "yaml lint"
#(yamllint ${MANIFEST_PATH} && exit 0)
#if [ $? -ne 0 ]; then
#    echo "yamllint is not pleased"
#    # exit 1
#fi

echo "validate manifest $(Emphasize $MANIFEST_PATH)"
docker run -t -v ${MANIFEST_DIR}:/fixtures ${KUBECONFORM_IMAGE}:${KUBECONFORM_VERSION} -strict -verbose -ignore-missing-schemas /fixtures/${MANIFEST_FILE}
# &> $KUBEVAL_OUTPUT

if [ $? -ne 0 ]; then
    echo $(Emphasize red "kubeconform fail")
    echo 
    exit 1
fi

if [[ ! -z $(grep -e '^\s*axdd\.s.uw\.edu\/security-policy\: applied\s*$' "$MANIFEST_PATH") ]]; then
  echo scan for security policies
  docker run -ti -v ${MANIFEST_DIR}/:/tf --env LOG_LEVEL=INFO $CHECKOV_IMAGE --quiet --skip-check $CHECKOV_SKIP_CHECKS -f /tf/$MANIFEST_FILE &> ${CHECKOV_OUTPUT}
  if [ $? -ne 0 ]; then
      cat ${CHECKOV_OUTPUT}
      exit 1
  fi
fi

echo $(Emphasize green "valid deployment")
