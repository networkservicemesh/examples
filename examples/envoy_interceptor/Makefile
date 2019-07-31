NAME = envoy_interceptor
DESCRIPTION = "Run Envoy as a NS Endpoint"
CONTAINERS = envoy-nse
PODS = simple-client envoy-nse
NETWORK_SERVICES = web-service
CHECK = export ITERATIONS=10 && export BATCHES=1 && scripts/check_envoy.sh

include $(TOP)/mk/targets.mk
