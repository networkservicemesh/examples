NAME = packet-filtering
DESCRIPTION = "Packet filtering - usecase for the CNF Testbed"
CONTAINERS =
AUX_CONTAINERS = universal-cnf-vppagent
PODS = simple-client ucnf-client packet-filter gateway
NETWORK_SERVICES = packet-filtering
CHECK = scripts/check_packet_filtering.sh

# should not fail go linter
FAIL_GOLINT =

include $(TOP)/mk/targets.mk
