# Kiknos base VPN NSE

This replaces the VPP agent in the universal-cnf with the Kiknos VPP aio-agent

# Prerequisites
Please follow the instructions on where the NSM project should be in the [Examples README.md](../../README.md)

# Testing 

Follow the following sequence to verify that the NSE works as expected. All `make` commands should be given from the project root.

```bash
# Deploy the NSM
make kind-start

SPIRE_ENABLED=false INSECURE=true make helm-init helm-install-nsm

# Build the docker image # Using a custom build untill the Kiknos issue is resolved
VPP_AGENT=rastislavszabo/vl3_ucnf-vl3-nse:v4 TAG=kiknos make k8s-universal-cnf-save

# Load the image in the kind cluster
make k8s-universal-cnf-load-images

# Deploy the kiknos NSE and test clients
make kiknos-nse-deploy

# Check that the clients can connect to the endpoint
make kiknos-check-deployment

```