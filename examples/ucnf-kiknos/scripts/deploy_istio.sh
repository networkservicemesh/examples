#!/usr/bin/env bash

function print_usage() {
    echo "1"
}

for i in "$@"; do
  case $i in
  --cluster=*)
    CLUSTER="${i#*=}"
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

echo "Installing Istio control plane"
kubectl --context "$CLUSTER" apply -f ./examples/ucnf-kiknos/k8s/istio_cfg.yaml

sleep 2

kubectl --context "$CLUSTER" wait -n istio-system --timeout=150s --for condition=Ready --all pods || exit $?
