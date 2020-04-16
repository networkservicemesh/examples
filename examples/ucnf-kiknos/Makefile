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

.PHONY:kiknos-nse-deploy-client
kiknos-nse-deploy-client:
	helm template examples/ucnf-kiknos/helm/client | kubectl apply -f -

.PHONY:kiknos-nse-deploy
kiknos-nse-deploy: kiknos-nse-deploy-endpoint kiknos-nse-deploy-client

.PHONY:delete-kiknos-nse
delete-kiknos-nse:
	helm template examples/ucnf-kiknos/helm/kiknos_vpn_endpoint | kubectl delete -f -

.PHONY:delete-kiknos-clients
delete-kiknos-clients:
	helm template examples/ucnf-kiknos/helm/client | kubectl delete -f -

.PHONY: kiknos-check-deployment
kiknos-check-deployment:
	./examples/ucnf-kiknos/scripts/check_icmp.sh

.PHONY: kiknos-clean-deployment
kiknos-clean-deployment: delete-kiknos-nse delete-kiknos-clients
