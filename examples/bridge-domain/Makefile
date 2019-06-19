NAME = bridge-domain
CONTAINERS = bridge
AUX_CONTAINERS =
PODS = simple-client bridge
NETWORK_SERVICES = #bridge-domain
CHECK = scripts/check_bridge_domain.sh

export VPP_AGENT=ligato/vpp-agent:v2.1.1

include $(TOP)/mk/targets.mk
