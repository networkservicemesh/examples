#!/usr/bin/env bash

CLUSTER1=${CLUSTER1:-kiknos-demo-1}
CLUSTER2=${CLUSTER2:-kiknos-demo-2}

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
