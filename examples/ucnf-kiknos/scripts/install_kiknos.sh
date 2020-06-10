#!/usr/bin/env bash

NSE_ORG=${NSE_ORG:-mmatache}
NSE_TAG=${NSE_TAG:-kiknos}
PULL_POLICY=${PULL_POLICY:-IfNotPresent}
SERVICE_NAME=${SERVICE_NAME:-hello-world}
DELETE=${DELETE:-false}
OPERATION=${OPERATION:-apply}

function print_usage() {
    echo "1"
}

for i in "$@"; do
  case $i in
  --cluster=*)
    CLUSTER="${i#*=}"
    ;;
  --cluster-ref=*)
    CLUSTER_REF="${i#*=}"
    ;;
  --pull-policy=*)
    PULL_POLICY="${i#*=}"
    ;;
  --delete)
    OPERATION=delete
    ;;
  --dry-run)
    DRY_RUN=true
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

if [[ "$DRY_RUN" == true ]]; then
  source $(pwd)/$(dirname "${BASH_SOURCE[0]}")/dry_run.sh
fi

pushd $(dirname "${BASH_SOURCE[0]}")/../../../

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
  if [[ "$OPERATION" == "delete" ]]; then
    exit 0
  fi

  kubectl --context "$cluster" wait -n default --timeout=150s --for condition=Ready --all pods -l k8s-app
  kubectl --context "$cluster" wait -n default --timeout=150s --for condition=Ready --all pods -l networkservicemesh.io/app
}

if [[ -n "$CLUSTER_REF" ]]; then
    POD_NAME=$(kubectl --context "$CLUSTER_REF" get pods -o name | grep endpoint | cut -d / -f 2)
    IP_ADDR=$(kubectl --context "$CLUSTER_REF" exec -it "$POD_NAME" -- ip addr | grep 'global[\w ]*eth0' | grep inet | awk '{print $2}' | cut -d / -f 1)

    echo POD_NAME $POD_NAME
    echo IP_ADDR $IP_ADDR

    performNSE "$CLUSTER" --set strongswan.network.remoteAddr="$IP_ADDR" \
      --set strongswan.network.localSubnet=172.31.23.0/24 \
      --set strongswan.network.remoteSubnets="{172.31.22.0/24}"
    exit 0
fi

performNSE "$CLUSTER" --set strongswan.network.localSubnet=172.31.22.0/24 \
  --set strongswan.network.remoteSubnets="{172.31.23.0/24,192.168.254.0/24}"
