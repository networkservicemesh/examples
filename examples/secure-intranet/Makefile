NAME = secure-intranet
DESCRIPTION = "The *Sarah* Secure Intranet Connectivity implementation"
CONTAINERS = vppagent-endpoint
AUX_CONTAINERS = proxy-nginx proxy-sidecar-nse
PODS = simple-client vppagent-passthrough vppagent-acl-filter gateway
NETWORK_SERVICES = secure-intranet
CHECK = scripts/check_secure_intranet.sh

include $(TOP)/mk/targets.mk
