#!/usr/bin/env bash

CLUSTER1=${CLUSTER1:-cl1}
CLUSTER2=${CLUSTER2:-cl2}

helloIPs=()
for hello in $(kubectl --context "kind-$CLUSTER1" get pods -l app=icmp-responder -o=name); do
  podIp=$(kubectl --context "kind-$CLUSTER1" exec "$hello" -c helloworld -- ip addr show dev nsm0 | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}')
  echo "Detected pod with nsm interface ip: $podIp"
  helloIPs+=("$podIp")
done

for hello in $(kubectl --context "kind-$CLUSTER2" get pods -l app=icmp-responder -o=name); do
  for ip in "${helloIPs[@]}"; do
    kubectl --context "kind-$CLUSTER2" exec "$hello" -c helloworld -- curl "http://$ip:5000/hello"
  done
done
