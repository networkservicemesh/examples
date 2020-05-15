#!/usr/bin/env bash

CLUSTER1=${CLUSTER1:-kiknos-demo-1}
CLUSTER2=${CLUSTER2:-kiknos-demo-2}

print_usage() {
  echo "$(basename "$0") - Deploy NSM Kiknos topology. All properties can also be provided through env variables

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

helloIPs=()
for hello in $(kubectl --context "$CLUSTER1" get pods -l app=icmp-responder -o=name); do
  podIp=$(kubectl --context "$CLUSTER1" exec "$hello" -c helloworld -- ip addr show dev nsm0 | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}')
  echo "Detected pod with nsm interface ip: $podIp"
  helloIPs+=("$podIp")
done

for hello in $(kubectl --context "$CLUSTER2" get pods -l app=icmp-responder -o=name); do
  for ip in "${helloIPs[@]}"; do
    kubectl --context "$CLUSTER2" exec "$hello" -c helloworld -- curl -s "http://$ip:5000/hello"
  done
done
rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
