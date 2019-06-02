
NAME = proxy
CONTAINERS = nginx sidecar-nse proxy-nsc
PODS = proxy-nsc nginx-nse
NETWORK_SERVICES = web-service
CHECK = export ITERATIONS=10 && export BATCHES=1 && scripts/verify_proxy_nsc.sh

include $(TOP)/mk/targets.mk
