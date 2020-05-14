#!/bin/bash

CLUSTER1=${CLUSTER1:-kind-cl1}
CLUSTER2=${CLUSTER2:-kind-cl2}
SERVICE_NAME=${SERVICE_NAME:-icmp-responder}

echo "Retrieving IP addr of interface"
POD_NAME=$(kubectl --context "$CLUSTER1" get pods -o name | grep icmp-responder | cut -d / -f 2)
IP_ADDR=$(kubectl --context "$CLUSTER1" exec -it "$POD_NAME" -- ip addr | grep "global eth0" | grep inet | awk '{print $2}' | cut -d / -f 1)

nsePod=$(kubectl --context "$CLUSTER2" get pods -l "networkservicemesh.io/app=${SERVICE_NAME}" -o=name)
kubectl --context "$CLUSTER2" exec -it "$nsePod" -- ping -c 4 "$IP_ADDR"
echo "Starting VPN"
kubectl --context "$CLUSTER2" exec -it "$nsePod" -- ipsec up kiknos