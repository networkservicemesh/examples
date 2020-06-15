include $(TOP)/mk/targets.mk

CLUSTER ?= kiknos-demo-1
ORG = vladcodaniel
TAG = kiknos
CLUSTER_REF ?=
AWS_KEY_PAIR ?= kiknos-asa
override VPP_AGENT = ciscolabs/kiknos:latest

# BUILD_IMAGE sets whether to build the image or not
BUILD_IMAGE = "true"

# PROVISION_MODE the mode to provision the built image
# one of "push" or "kind-load"
# not relevant if $BUILD_IMAGE is not true
PROVISION_MODE = "push"

# DEPLOY_ISTIO sets whether to deploy istio gateway or not
DEPLOY_ISTIO = "true"

KIND_CLUSTER_NAME = $(CLUSTER)

DRY_RUN ?= false

SPIRE_ENABLED ?= false
INSECURE ?= true

SERVICE_NAME ?= hello-world

ifeq ($(DRY_RUN), true)
with_dry_run=source $(TOP)/examples/ucnf-kiknos/scripts/dry_run.sh;
endif

provide-image: k8s-universal-cnf-save

ifeq ($(PROVISION_MODE), "push")
provide-image: docker-push
endif

ifeq ($(PROVISION_MODE), "kind-load")
provide-image: k8s-universal-cnf-load-images
endif


docker-push:
	@$(with_dry_run) docker push "$(ORG)/universal-cnf-vppagent:$(TAG)"

create-kind:
	@[[ -n `kind get clusters | grep $(CLUSTER)` ]] && echo "Cluster $(CLUSTER) already present, skipping create_kind rule" && exit 0;\
	$(with_dry_run) \
	kind create cluster --name $(CLUSTER);\
	kubectl config rename-context "kind-$(CLUSTER)" $(CLUSTER)

delete-kind:
	-@$(with_dry_run) kind delete cluster --name $(CLUSTER)

create-aws:
	@[[ -n `aws eks list-clusters --output=text | grep $(CLUSTER)` ]] && echo "Cluster $(CLUSTER) already present on aws, skipping create_aws rule" && exit 0;\
	$(with_dry_run) \
	python $(TOP)/examples/ucnf-kiknos/scripts/pyaws/create_cluster.py --name $(CLUSTER1) $(if $(F),--ref $(CLUSTER_REF)) --open-sg;\
	aws eks update-kubeconfig --name="$(CLUSTER)" --alias "$(CLUSTER1)"

delete-aws:
	-@$(with_dry_run) eksctl delete cluster --name="$(CLUSTER)"

ifeq ($(AWS), "true")
create-cluster: create-aws
delete-cluster: delete-aws
else
create-cluster: create-kind
delete-cluster: delete-kind
endif

deploy-nsm: create-cluster helm-init helm-install-nsm
	@$(with_dry_run) kubectl config use-context "$(CLUSTER)"

ifeq ($(BUILD_IMAGE), "true")
deploy-kiknos: provide-image
endif

deploy-kiknos: deploy-nsm
	@$(with_dry_run) $(TOP)/examples/ucnf-kiknos/scripts/deploy_kiknos.sh --cluster=$(CLUSTER)

deploy-istio: deploy-kiknos
	@$(with_dry_run) $(TOP)/examples/ucnf-kiknos/scripts/deploy_istio.sh --cluster=$(CLUSTER)

ifeq ($(DEPLOY_ISTIO), "true")
deploy-client: deploy-istio
endif

deploy-client: deploy-kiknos
	@$(with_dry_run) $(TOP)/examples/ucnf-kiknos/scripts/deploy_clients.sh --cluster=$(CLUSTER) #--istio_client

start-vpn: deploy-client
	@$(with_dry_run) $(TOP)/examples/ucnf-kiknos/scripts/start_vpn.sh --cluster=$(CLUSTER) --service_name=$(SERVICE_NAME)

deploy-asa: create-cluster
	@$(with_dry_run) $(TOP)/examples/ucnf-kiknos/scripts/deploy_asa.sh --cluster=$(CLUSTER) --cluster-ref=$(CLUSTER_REF) --aws_key_pair=$(AWS_KEY_PAIR)

delete-context:
	-@$(with_dry_run) kubectl config delete-context $(CLUSTER)

clear: delete-context delete-cluster
