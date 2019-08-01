NAME = packet-filtering
DESCRIPTION = "Packet filtering - usecase for the CNF Testbed"
CONTAINERS =
AUX_CONTAINERS = universal-cnf-vppagent
PODS = simple-client ucnf-client packet-filter gateway
NETWORK_SERVICES = packet-filtering
CHECK = scripts/check_packet_filtering.sh

export VPP_AGENT=ligato/vpp-agent:v2.1.1

# should not fail go linter
FAIL_GOLINT =

include $(TOP)/mk/targets.mk
	