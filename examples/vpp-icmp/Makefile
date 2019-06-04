NAME = vpp-icmp
CONTAINERS = vppagent-client vppagent-endpoint
PODS = vppagent-client vppagent-endpoint
# NETWORK_SERVICES = icmp-responder
CHECK = scripts/check_icmp.sh

export VPP_AGENT=ligato/vpp-agent:v2.1.1

include $(TOP)/mk/targets.mk
