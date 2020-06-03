#!/bin/bash

CLUSTER=${CLUSTER:-kiknos-demo-2}
SERVICE_NAME=${SERVICE_NAME:-hello-world}

nsePod=$(kubectl --context "$CLUSTER" get pods -l "networkservicemesh.io/app=${SERVICE_NAME}" -o=name)
kubectl --context "$CLUSTER" exec -it "$nsePod" -- ipsec up kiknos