#!/usr/bin/env bash

CLUSTER1=${CLUSTER1:-kind-cl1}
CLUSTER2=${CLUSTER2:-kind-cl2}
SERVICENAME=${SERVICENAME:-icmp-responder}

nsePod=$(kubectl --context "$CLUSTER2" get pods -l "networkservicemesh.io/app=${SERVICENAME}" -o=name)

echo "Found NSE pod with name: $nsePod"

retries=0
kiknosLog=""
while [ "$kiknosLog" != "connection 'kiknos' established successfully" ]; do
  if [ $retries == 10 ]; then
    echo "failed to establish 'kiknos' connection after: $retries retries"
    exit 1
  fi

  echo "Executing: ipsec up kiknos"
  kiknosLog=$(kubectl --context "$CLUSTER2" exec -it "$nsePod" -- ipsec up kiknos | grep "established successfully" | tr -d '\n\r')
  (( retries++ ))
done

echo "$kiknosLog with $((--retries)) retries"

kubectl --context "$CLUSTER2" exec -it "$nsePod" -- vppctl sh inter | grep ipip

helloIPs=()
helloPodsArr1=$(kubectl --context "$CLUSTER1" get pods -l app=icmp-responder -o=name)

for hello in ${helloPodsArr1[@]}; do
  podIp=$(kubectl --context "$CLUSTER1" exec -it "$hello" -- ip addr show dev nsm0 | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}')
  echo "Detected pod with nsm interface ip: $podIp"
  helloIPs+=("$podIp")
done

helloPodsArr2=$(kubectl --context "$CLUSTER2" get pods -l app=icmp-responder -o=name)
for hello in ${helloPodsArr2[@]}; do
  for ip in "${helloIPs[@]}"; do
    kubectl --context "$CLUSTER2" exec -it "$hello" -- curl "http://$ip:5000/hello"
  done
done
