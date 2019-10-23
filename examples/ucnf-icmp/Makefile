NAME = ucnf-icmp
DESCRIPTION = "Basic ICMP reposnder based on the Universal CNF"
CONTAINERS =
AUX_CONTAINERS = universal-cnf-vppagent
PODS = ucnf-client ucnf-endpoint
NETWORK_SERVICES = icmp-responder
CHECK = scripts/check_icmp.sh

export VPP_AGENT=ligato/vpp-agent:v2.3.0

# should not fail go linter
FAIL_GOLINT =

include $(TOP)/mk/targets.mk
