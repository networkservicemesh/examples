#!/usr/bin/env bash

# Topology information
CLUSTER=${CLUSTER:-kind-cl1}
SERVICE_NAME=${SERVICE_NAME:-icmp-responder}

pushd "$(dirname "$0")/../../../"

print_usage() {
  echo "$(basename "$0") - Deploy NSM Kiknos topology. All properties can also be provided through env variables

NOTE: The defaults will change to the env values for the ones set.

Usage: $(basename "$0") [options...]
Options:
  --cluster             Name of Kind cluster one - Represents the client network            env var: CLUSTER         - (Default: $CLUSTER)
  --service_name        NSM service                                                         env var: SERVICE_NAME     - (Default: $SERVICE_NAME)
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

echo "Installing Istio control plane"
kubectl --context "$CLUSTER" apply -f ./examples/ucnf-kiknos/k8s/istio_cfg.yaml

helm template ./examples/ucnf-kiknos/helm/istio_ingress --set nsm.serviceName="$SERVICE_NAME" | kubectl --context "$CLUSTER" apply -f -
sleep 1
kubectl --context "$CLUSTER" wait -n istio-system --timeout=500s --for condition=Ready --all pods