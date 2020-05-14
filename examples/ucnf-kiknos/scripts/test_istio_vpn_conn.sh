#!/usr/bin/env bash

CLUSTER1=${CLUSTER1:-kind-cl1}
CLUSTER2=${CLUSTER2:-kind-cl2}

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

for hello in $(kubectl --context "$CLUSTER2" get pods -l app=icmp-responder -o=name); do
  for ip in "${helloIPs[@]}"; do
    echo "------------------------- Source $hello -------------------------"
    curl_to "$CLUSTER2" "http://$ip/hello"
    curl_to "$CLUSTER2" "http://$ip/hello-v2"
    curl_to "$CLUSTER2" "http://$ip:8000/hello"
    curl_to "$CLUSTER2" "http://$ip:8000/hello-v2"
    echo "-----------------------------------------------------------------------------------------------------"
  done
done