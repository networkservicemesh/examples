NAME = ucnf-kiknos
DESCRIPTION = "Basic ICMP reposnder based on the Universal CNF with Kiknos VPP agent"
CONTAINERS =
AUX_CONTAINERS = universal-cnf-vppagent
PODS = ucnf-client vpn-endpoint
NETWORK_SERVICES = icmp-responder
CHECK = scripts/check_icmp.sh

export VPP_AGENT=ciscolabs/kiknos:latest


# should not fail go linter
FAIL_GOLINT =

include $(TOP)/mk/targets.mk

.PHONY:kiknos-nse-deploy-endpoint
kiknos-nse-deploy-endpoint:
	helm template examples/ucnf-kiknos/helm/kiknos_vpn_endpoint | kubectl apply -f -
	kubectl wait -n default --timeout=150s --for condition=Ready --all pods --selector k8s-app
	kubectl wait -n default --timeout=150s --for condition=Ready --all pods --selector networkservicemesh.io/app

.PHONY:kiknos-nse-deploy-hello
kiknos-nse-deploy-hello:
	helm template examples/ucnf-kiknos/helm/vl3_hello | kubectl apply -f -

.PHONY:kiknos-nse-delete-hello
kiknos-nse-delete-hello:
	helm template examples/ucnf-kiknos/helm/vl3_hello | kubectl delete -f -

.PHONY:kiknos-nse-deploy
kiknos-nse-deploy: kiknos-nse-deploy-endpoint kiknos-nse-deploy-hello

.PHONY:kiknos-nse-delete-endpoint
kiknos-nse-delete-endpoint:
	helm template examples/ucnf-kiknos/helm/kiknos_vpn_endpoint | kubectl delete -f -


.PHONY: kiknos-check-deployment
kiknos-check-deployment:
	@./examples/ucnf-kiknos/scripts/check_icmp.sh

.PHONY: kiknos-clean-deployment
kiknos-clean-deployment: kiknos-nse-delete-hello kiknos-nse-delete-endpoint
