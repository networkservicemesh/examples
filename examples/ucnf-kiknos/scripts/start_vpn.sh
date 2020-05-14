#!/bin/bash

CLUSTER1=${CLUSTER1:-kind-cl1}
CLUSTER2=${CLUSTER2:-kind-cl2}
SERVICE_NAME=${SERVICE_NAME:-icmp-responder}

nsePod=$(kubectl --context "$CLUSTER2" get pods -l "networkservicemesh.io/app=${SERVICE_NAME}" -o=name)
echo "Starting VPN"
kubectl --context "$CLUSTER2" exec -it "$nsePod" -- ipsec up kiknos