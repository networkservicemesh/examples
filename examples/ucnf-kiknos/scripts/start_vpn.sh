#!/bin/bash

CLUSTER=${CLUSTER:-kiknos-demo-2}
SERVICE_NAME=${SERVICE_NAME:-icmp-responder}

nsePod=$(kubectl --context "$CLUSTER" get pods -l "networkservicemesh.io/app=${SERVICE_NAME}" -o=name)
kubectl --context "$CLUSTER" exec -it "$nsePod" -- ipsec up kiknos