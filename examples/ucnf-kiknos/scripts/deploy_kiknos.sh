#!/usr/bin/env bash

NSE_ORG=${NSE_ORG:-mmatache}
NSE_TAG=${NSE_TAG:-kiknos}
PULL_POLICY=${PULL_POLICY:-IfNotPresent}
SERVICE_NAME=${SERVICE_NAME:-hello-world}
DELETE=${DELETE:-false}
OPERATION=${OPERATION:-apply}
SUBNET_IP=${SUBNET_IP:-192.168.254.0}

function print_usage() {
    echo "$(basename "$0") - Deploy NSM Kiknos topology. All properties can also be provided through env variables

NOTE: The defaults will change to the env values for the ones set.

Usage: $(basename "$0") [options...]
Options:
  --cluster             Cluster name                                                        env var: CLUSTER          - (Default: $CLUSTER)
  --cluster-ref         Cluster reference                                                   env var: CLUSTER_REF      - (Default: $CLUSTER_REF)
  --org                 Docker image org                                                    env var: NSE_ORG          - (Default: $NSE_ORG)
  --tag                 Docker image tag                                                    env var: NSE_TAG          - (Default: $NSE_TAG)
  --pull-policy         Pull policy for the NSE image                                       env var: PULL_POLICY      - (Default: $PULL_POLICY)
  --service-name        NSM service                                                         env var: SERVICE_NAME     - (Default: $SERVICE_NAME)
  --delete              Delete NSE                                                          env var: DELETE           - (Default: $DELETE)
  --subnet-ip           IP for the remote ASA subnet (without the mask, ex: 192.168.254.0)  env var: SUBNET_IP        - (Default: $SUBNET_IP)
  --help -h             Help
" >&2
}

for i in "$@"; do
  case $i in
  --org=*)
    NSE_ORG="${i#*=}"
    ;;
  --tag=*)
    NSE_TAG="${i#*=}"
    ;;
  --cluster=*)
    CLUSTER="${i#*=}"
    ;;
  --cluster-ref=*)
    CLUSTER_REF="${i#*=}"
    ;;
  --pull-policy=*)
    PULL_POLICY="${i#*=}"
    ;;
  --service-name=*)
    SERVICE_NAME="${i#*=}"
    ;;
  --subnet-ip=*)
    SUBNET_IP="${i#*=}"
    ;;
  --delete)
    OPERATION=delete
    ;;
  -h | --help)
    print_usage
    exit 0
    ;;
  *)
    print_usage
    exit 1
    ;;
  esac
done

[[ -z "$CLUSTER" ]] && echo "env var: CLUSTER is required!" && print_usage && exit 1

pushd "$(dirname "${BASH_SOURCE[0]}")/../../../" || exit 1

# Perform the given kubectl operation for the NSE
function performNSE() {
  local cluster=$1; shift
  local opts=$*
  echo "apply NSE into cluster: $cluster"
  helm template ./examples/ucnf-kiknos/helm/kiknos_vpn_endpoint \
    --set org="$NSE_ORG" \
    --set tag="$NSE_TAG" \
    --set pullPolicy="$PULL_POLICY" \
    --set nsm.serviceName="$SERVICE_NAME" $opts | kubectl --context "$cluster" $OPERATION -f -

  CONDITION="condition=Ready"
  if [[ ${OPERATION} = delete ]]; then
    CONDITION="delete"
  fi

  echo "Waiting for kiknos pods condition to be '$CONDITION'"
  kubectl --context "$cluster" wait -n default --timeout=150s --for ${CONDITION} --all pods -l k8s-app=kiknos-etcd
  kubectl --context "$cluster" wait -n default --timeout=150s --for ${CONDITION} --all pods -l networkservicemesh.io/app=${SERVICE_NAME}

  if [[ ${OPERATION} = delete ]]; then
    echo "Delete '${SERVICE_NAME}' network service if exists"
    kubectl --context "$cluster" delete networkservices.networkservicemesh.io ${SERVICE_NAME}
  fi
}

if [[ -n "$CLUSTER_REF" ]]; then
    POD_NAME=$(kubectl --context "$CLUSTER_REF" get pods -o name | grep endpoint | cut -d / -f 2)
    IP_ADDR=$(kubectl --context "$CLUSTER_REF" exec -it "$POD_NAME" -- ip addr | grep -E "global (dynamic )?eth0" | grep inet | awk '{print $2}' | cut -d / -f 1)

    performNSE "$CLUSTER" --set strongswan.network.remoteAddr="$IP_ADDR" \
      --set strongswan.network.localSubnet=172.31.23.0/24 \
      --set strongswan.network.remoteSubnets="{172.31.22.0/24}"
    exit 0
fi

performNSE "$CLUSTER" --set strongswan.network.localSubnet=172.31.22.0/24 \
  --set strongswan.network.remoteSubnets="{172.31.23.0/24,$SUBNET_IP/24}"
