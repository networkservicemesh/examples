#!/usr/bin/env bash

SERVICE_NAME=${SERVICE_NAME:-hello-world}

function print_usage() {
    echo "$(basename "$0") - Deploy NSM Kiknos topology. All properties can also be provided through env variables

NOTE: The defaults will change to the env values for the ones set.

Usage: $(basename "$0") [options...]
Options:
  --cluster             Cluster name            env var: CLUSTER          - (Default: $CLUSTER)
  --service-name        NSM service             env var: SERVICE_NAME     - (Default: $SERVICE_NAME)
  --help -h             Help
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

nsePod=$(kubectl --context "$CLUSTER" get pods -l "networkservicemesh.io/app=${SERVICE_NAME}" -o=name)

kubectl --context "$CLUSTER" exec -it "$nsePod" -- ipsec up kiknos