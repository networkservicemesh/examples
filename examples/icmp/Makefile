NAME = icmp
DESCRIPTION = "Basic kernel interface ICMP reposnder"
CONTAINERS =
AUX_CONTAINERS = proxy-sidecar-nse
PODS = simple-client simple-endpoint
NETWORK_SERVICES = icmp-responder
CHECK = scripts/check_icmp.sh

# should not fail go linter
FAIL_GOLINT =

include $(TOP)/mk/targets.mk
