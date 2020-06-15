#!/usr/bin/env bash

# Topology information
SERVICE_NAME=${SERVICE_NAME:-hello-world}
ISTIO_CLIENT=${ISTIO_CLIENT:-false}
OPERATION=${OPERATION:-apply}

pushd "$(dirname "$0")/../../../"

print_usage() {
  echo "$(basename "$0") - Deploy NSM Kiknos topology. All properties can also be provided through env variables

NOTE: The defaults will change to the env values for the ones set.

Usage: $(basename "$0") [options...]
Options:
  --cluster             Name of Kind cluster - Represents the client network            env var: CLUSTER         - (Default: $CLUSTER)
  --service_name         NSM service                                                         env var: SERVICE_NAME    - (Default: $SERVICE_NAME)
  --istio_client         If an istio client should be deployed instead of a regular client   env var: ISTIO_CLIENT    - (Default: $ISTIO_CLIENT)
  --delete
" >&2

}

for i in "$@"; do
  case $i in
  --cluster=*)
    CLUSTER="${i#*=}"
    ;;
  --service_name=*)
    SERVICE_NAME="${i#*=}"
    ;;
  --istio_client)
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
  helm template ./examples/ucnf-kiknos/helm/istio_clients --set app=icmp-responder | kubectl --context "$CLUSTER" "$OPERATION" -f -
fi

echo "Waiting for client pods to be ready"
kubectl --context "$CLUSTER" wait -n default --timeout=150s --for condition=Ready --all pods -l "app=$SERVICE_NAME" &
