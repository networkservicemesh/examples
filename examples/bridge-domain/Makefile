NAME = bridge-domain
DESCRIPTION = "A simple VPP bridge domain example"
CONTAINERS = bridge
AUX_CONTAINERS =
PODS = simple-client bridge
NETWORK_SERVICES = bridge-domain
CHECK = scripts/check_bridge_domain.sh

export VPP_AGENT=ligato/vpp-agent:v2.3.0

include $(TOP)/mk/targets.mk
