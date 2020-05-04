# Kiknos base VPN NSE

This replaces the VPP agent in the universal-cnf with the Kiknos VPP aio-agent

# Prerequisites
- Please follow the instructions on where the NSM project should be in the [Examples README.md](../../README.md)

# Versions
The script has been tested with the following versions
- kind v0.7.x
- helm v2.16.x
- kubectl v1.17.x - v.18.x
- kubernetes version v1.17.x
- NSM version 0.2.0
 
# Testing


`./examples/ucnf-kiknos/scripts/kind_topo.sh`
Starts 2 kind clusters configured with kiknos and then opens an IPSec tunnel between them.

`./examples/ucnf-kiknos/scripts/test_vpn_conn.sh`
Tests connectivity between pods in different clusters using a curl command

# Cleanup
The following command will delete the kind clusters.

`./examples/ucnf-kiknos/scripts/kind_topo.sh cleanup`

# Known issues
These issues require further investigation:

1. If the NSE restarts it loses all the interfaces  
