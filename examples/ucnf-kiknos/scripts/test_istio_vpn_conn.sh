#!/usr/bin/env bash

CLUSTER1=${CLUSTER1:-kiknos-demo-1}
CLUSTER2=${CLUSTER2:-kiknos-demo-2}
SERVICE_NAME=${SERVICE_NAME:-hello-world}

print_usage() {
  echo "$(basename "$0") - Test Istio VPN connectivity. All properties can also be provided through env variables

NOTE: The defaults will change to the env values for the ones set.

Usage: $(basename "$0") [options...]
Options:
  --cluster1            Name of Kind cluster one - Represents the client network            env var: CLUSTER1         - (Default: $CLUSTER1)
  --cluster2            Name of Kind cluster two - Represents the VPN Gateway               env var: CLUSTER2         - (Default: $CLUSTER2)
  --help -h             Help
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

function curl_to() {
  local cluster=$1; shift
  local address=$1; shift
  echo "Connecting to: $address"
  kubectl --context "$cluster" exec "$hello" -c helloworld -- curl -s "$address"
}

helloIPs=()
for hello in $(kubectl --context "$CLUSTER1" get pods -n istio-system -l app=istio-ingressgateway -o=name); do
  podIp=$(kubectl --context "$CLUSTER1" -n istio-system exec "$hello" -c istio-proxy -- ip addr show dev nsm0 | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}')
  echo "Detected pod with nsm interface ip: $podIp"
  helloIPs+=("$podIp")
done

for hello in $(kubectl --context "$CLUSTER2" get pods -l "app=$SERVICE_NAME" -o=name); do
  for ip in "${helloIPs[@]}"; do
    echo "------------------------- Source $hello -------------------------"
    curl_to "$CLUSTER2" "http://$ip/hello"
    curl_to "$CLUSTER2" "http://$ip/hello-v2"
    curl_to "$CLUSTER2" "http://$ip:8000/hello"
    curl_to "$CLUSTER2" "http://$ip:8000/hello-v2"
    echo "-----------------------------------------------------------------------------------------------------"
  done
done

rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi