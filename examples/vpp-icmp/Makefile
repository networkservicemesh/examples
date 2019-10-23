NAME = vpp-icmp
DESCRIPTION = "Basic memif interface ICMP reposnder with VPP"
CONTAINERS = vppagent-client vppagent-endpoint
PODS = vppagent-client vppagent-endpoint
NETWORK_SERVICES = icmp-responder
CHECK = scripts/check_icmp.sh

export VPP_AGENT=ligato/vpp-agent:v2.3.0

include $(TOP)/mk/targets.mk
