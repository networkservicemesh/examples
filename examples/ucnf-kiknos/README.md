# Kiknos base VPN NSE

This replaces the VPP agent in the universal-cnf with the Kiknos VPP aio-agent

# Prerequisites
- Please follow the instructions on where the NSM project should be in the [Examples README.md](../../README.md)
- helm v2.16.3
- kubectl v1.18.2
- NSM version 0.2.0

##### Kind deployment
- kind v0.7.0 

##### AWS deployment
- aws-cli v2.0.11
- eksctl v0.18.0
- python >= 2.7

# Testing

> :warning: **For the current version build image are available only with `ORG=vladcodaniel` env **

- deploy on aws `make kiknos-aws`
- deploy on kind `make kiknos-kind`
- test connectivity `make kiknos-test-conn` 


# Cleanup
The following command will delete the kind clusters.

`./examples/ucnf-kiknos/scripts/kind_topo.sh cleanup`

# Known issues
These issues require further investigation:

1. If the NSE restarts it loses all the interfaces  
