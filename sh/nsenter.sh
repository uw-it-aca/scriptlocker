#!/bin/bash

# https://github.com/alexei-led/nsenter
# Create privileged pod and uses the nsenter command to start a shell on the host as root
# automatically tears itself down on exit

if [ $# == 0 ] || [ $1 == "-h" ] || [ $1 == "--help" ]; then
    echo "Get a shell with root privileges on specified Kubernetes node"
    echo "Usage: $0 k8s_node_name"
    exit 1
fi

# set -x

node=${1}
nodeName=$(kubectl get node ${node} -o template --template='{{index .metadata.labels "kubernetes.io/hostname"}}')
nodeSelector='"nodeSelector": { "kubernetes.io/hostname": "'${nodeName:?}'" },'
podName=${USER}-nsenter-${node}
# convert @ to -
podName=${podName//@/-}
# convert . to -
podName=${podName//./-}
# truncate podName to 63 characters which is the kubernetes max length for it
podName=${podName:0:63}

echo "With great power comes great responsibility"

kubectl run ${podName:?} --restart=Never -it --rm --image overriden --overrides '
{
  "spec": {
    "hostPID": true,
    "hostNetwork": true,
    '"${nodeSelector?}"'
    "tolerations": [{
        "operator": "Exists"
    }],
    "containers": [
      {
        "name": "nsenter",
        "image": "alexeiled/nsenter",
        "command": [
          "/nsenter", "--all", "--target=1", "--", "su", "-"
        ],
        "stdin": true,
        "tty": true,
        "securityContext": {
          "privileged": true
        },
        "resources": {
          "requests": {
            "cpu": "10m"
          }
        }
      }
    ]
  }
}' --attach "$@"
