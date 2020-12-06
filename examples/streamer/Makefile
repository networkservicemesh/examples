NAME = streamer
DESCRIPTION = "A simple ffmpeg based streamer"
CONTAINERS = streamer
AUX_CONTAINERS = proxy-proxy-nsc proxy-sidecar-nse
PODS = proxy-nsc source
NETWORK_SERVICES = streamer
CHECK =

# should not fail go linter
FAIL_GOLINT =

include $(TOP)/mk/targets.mk
