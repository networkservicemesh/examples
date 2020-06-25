#!/usr/bin/env bash

# Topology information
SERVICE_NAME=${SERVICE_NAME:-hello-world}
ISTIO_CLIENT=${ISTIO_CLIENT:-false}
OPERATION=${OPERATION:-apply}

pushd "$(dirname "$0")/../../../"

print_usage() {
  echo "$(basename "$0") - Deploy NSM Clients. All properties can also be provided through env variables

NOTE: The defaults will change to the env values for the ones set.

Usage: $(basename "$0") [options...]
Options:
  --cluster             Cluster name                                                        env var: CLUSTER         - (Default: $CLUSTER)
  --service-name        NSM service                                                         env var: SERVICE_NAME    - (Default: $SERVICE_NAME)
  --istio-client        If an istio client should be deployed instead of a regular client   env var: ISTIO_CLIENT    - (Default: $ISTIO_CLIENT)
  --delete
" >&2

}

for i in "$@"; do
  case $i in
  --cluster=*)
    CLUSTER="${i#*=}"
    ;;
  --service-name=*)
    SERVICE_NAME="${i#*=}"
    ;;
  --istio-client)
    ISTIO_CLIENT=true
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

helm template ./examples/ucnf-kiknos/helm/vl3_hello --set nsm.serviceName="$SERVICE_NAME" | kubectl --context "$CLUSTER" "$OPERATION" -f -

if [[ "$ISTIO_CLIENT" == "true" ]]; then
  helm template ./examples/ucnf-kiknos/helm/istio_ingress --set nsm.serviceName="$SERVICE_NAME" | kubectl --context "$CLUSTER" "$OPERATION" -f -
  sleep 1
  echo "Waiting for Istio gateway to be ready"
  kubectl --context "$CLUSTER" wait -n istio-system --timeout=500s --for condition=Ready --all pods
  kubectl --context "$CLUSTER" label namespace default istio-injection=enabled
  helm template ./examples/ucnf-kiknos/helm/istio_clients --set app=${SERVICE_NAME} | kubectl --context "$CLUSTER" "$OPERATION" -f -
fi

CONDITION="condition=Ready"
if [[ ${OPERATION} = delete ]]; then
    CONDITION="delete"
fi

echo "Waiting for client pods condition to be '$CONDITION'"
kubectl --context "$CLUSTER" wait -n default --timeout=150s --for ${CONDITION} --all pods -l "app=$SERVICE_NAME"