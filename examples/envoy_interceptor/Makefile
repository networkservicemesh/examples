NAME = envoy_interceptor
CONTAINERS = envoy-nse
PODS = simple-client envoy-nse
CHECK = export ITERATIONS=10 && export BATCHES=1 && scripts/check_envoy.sh

include $(TOP)/mk/targets.mk