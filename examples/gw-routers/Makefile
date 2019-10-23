NAME = gw-routers
DESCRIPTION = "GW and Router - usecase for the CNF Testbed"
CONTAINERS =
AUX_CONTAINERS = universal-cnf-vppagent
PODS = router-left router-right gateway-left gateway-right
NETWORK_SERVICES = gw-routers
CHECK = scripts/check_gw_routers.sh

# should not fail go linter
FAIL_GOLINT =

include $(TOP)/mk/targets.mk
