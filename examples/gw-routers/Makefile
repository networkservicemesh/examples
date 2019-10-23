NAME = gw-routers
DESCRIPTION = "GW and Router - usecase for the CNF Testbed"
CONTAINERS =
AUX_CONTAINERS = universal-cnf-vppagent
PODS = router-left router-right gateway-left gateway-right
NETWORK_SERVICES = gw-routers
CHECK = scripts/check_gw_routers.sh

export VPP_AGENT=ligato/vpp-agent:v2.3.0

# should not fail go linter
FAIL_GOLINT =

include $(TOP)/mk/targets.mk
