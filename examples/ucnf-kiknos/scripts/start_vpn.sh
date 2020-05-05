#!/bin/bash

CLUSTER2=${CLUSTER2:-cl2}
SERVICE_NAME=${SERVICE_NAME:-icmp-responder}

nsePod=$(kubectl --context "kind-$CLUSTER2" get pods -l "networkservicemesh.io/app=${SERVICE_NAME}" -o=name)
kubectl --context "kind-$CLUSTER2" exec -it "$nsePod" -- ipsec up kiknos