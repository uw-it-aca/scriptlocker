#!/bin/bash

COPILOT_CLI_IMAGE=copilot_cli

usage() {
  echo "Usage: $0 [ -h ] [ -i <copilot_image> ] <path_to_application>"
}

while getopts ":h:i:" opt; do
  case $opt in
    h)  usage
        exit;;
    i) COPILOT_CLI_IMAGE="$OPTARG"
        ;;
    \?) echo "Invalid option -$OPTARG" >&2
        usage
        exit 1;;
  esac
done

shift $((OPTIND-1))

if [ "$#" -ne 1 ]; then
  echo "$0: missing application path"
  usage
  exit 1
fi

if [ -z "$(docker images -q ${COPILOT_CLI_IMAGE}:latest)" ]; then
    docker build -t $COPILOT_CLI_IMAGE .
fi

docker run --user ubuntu --workdir /app -it -v $1:/app/${1##*/} $COPILOT_CLI_IMAGE bash
