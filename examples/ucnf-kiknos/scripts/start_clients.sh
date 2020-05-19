#!/usr/bin/env bash

# Topology information
CLUSTER1=${CLUSTER:-kiknos-demo-1}
CLUSTER2=${CLUSTER:-kiknos-demo-2}
SERVICE_NAME=${SERVICE_NAME:-icmp-responder}
ISTIO_CLIENT=${ISTIO_CLIENT:-false}

pushd "$(dirname "$0")/../../../"

print_usage() {
  echo "$(basename "$0") - Deploy NSM Kiknos topology. All properties can also be provided through env variables

NOTE: The defaults will change to the env values for the ones set.

Usage: $(basename "$0") [options...]
Options:
  --cluster1             Name of Kind cluster one - Represents the client network            env var: CLUSTER         - (Default: $CLUSTER1)
  --cluster2             Name of Kind cluster one - Represents the client network            env var: CLUSTER         - (Default: $CLUSTER2)
  --service_name         NSM service                                                         env var: SERVICE_NAME    - (Default: $SERVICE_NAME)
  --istio_client         If an istio client should be deployed instead of a regular client   env var: ISTIO_CLIENT    - (Default: $ISTIO_CLIENT)
" >&2

}

for i in "$@"; do
  case $i in
  --cluster1=*)
    CLUSTER1="${i#*=}"
    ;;
  --cluster2=*)
    CLUSTER2="${i#*=}"
    ;;
  --service_name=*)
    SERVICE_NAME="${i#*=}"
    ;;
  --istio_client)
    ISTIO_CLIENT=true
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

helm template ./examples/ucnf-kiknos/helm/vl3_hello --set nsm.serviceName="$SERVICE_NAME" | kubectl --context "$CLUSTER1" apply -f -
helm template ./examples/ucnf-kiknos/helm/vl3_hello --set nsm.serviceName="$SERVICE_NAME" | kubectl --context "$CLUSTER2" apply -f -

if [ "$ISTIO_CLIENT" == "true" ]; then
  helm template ./examples/ucnf-kiknos/helm/istio_ingress --set nsm.serviceName="$SERVICE_NAME" | kubectl --context "$CLUSTER1" apply -f -
  sleep 1
  echo "Waiting for Istio gateway to be ready"
  kubectl --context "$CLUSTER1" wait -n istio-system --timeout=500s --for condition=Ready --all pods
  kubectl --context "$CLUSTER1" label namespace default istio-injection=enabled
  helm template ./examples/ucnf-kiknos/helm/istio_clients --set app=icmp-responder | kubectl --context "$CLUSTER1" apply -f -
fi

sleep 2
echo "Waiting for client pods to be ready"
kubectl --context "$CLUSTER2" wait -n default --timeout=150s --for condition=Ready --all pods -l app=icmp-responder &
kubectl --context "$CLUSTER1" wait -n default --timeout=150s --for condition=Ready --all pods -l app=icmp-responder &
wait

