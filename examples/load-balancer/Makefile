NAME = load-balancer
DESCRIPTION = "A simple VPP load-balancer example"
CONTAINERS = image
AUX_CONTAINERS =
PODS = load-balancer application-server
NETWORK_SERVICES = load-balancer-ns
CHECK = scripts/check_load_balancer.sh

include $(TOP)/mk/targets.mk
