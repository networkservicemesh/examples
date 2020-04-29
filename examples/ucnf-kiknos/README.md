# Kiknos base VPN NSE

This replaces the VPP agent in the universal-cnf with the Kiknos VPP aio-agent

# Prerequisites
Please follow the instructions on where the NSM project should be in the [Examples README.md](../../README.md)

# Testing 

`./examples/ucnf-kiknos/scripts/kind_topo.sh`

This command will start 2 kind clusters configured with kiknos to run IPSec tunnel between them.
Then it will call `./examples/ucnf-kiknos/scripts/test_vpn_conn.sh` which will open an IPSec tunnel between the clusters 
and test the connectivity between using a curl command.