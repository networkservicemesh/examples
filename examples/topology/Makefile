
NAME = topology
DESCRIPTION = "Using NSM to build arbitrary network topologies"
CONTAINERS = qrtr sidecar-nse sidecar-nsc
PODS = router1 router2 router3 router4 router5
NETWORK_SERVICES = topo
CHECK = export ITERATIONS=10 && export BATCHES=1 && scripts/check.sh

include $(TOP)/mk/targets.mk
