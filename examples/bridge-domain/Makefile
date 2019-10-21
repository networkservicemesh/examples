NAME = bridge-domain
DESCRIPTION = "A simple VPP bridge domain example"
CONTAINERS = bridge
AUX_CONTAINERS =
PODS = simple-client bridge
NETWORK_SERVICES = bridge-domain
CHECK = scripts/check_bridge_domain.sh

include $(TOP)/mk/targets.mk
