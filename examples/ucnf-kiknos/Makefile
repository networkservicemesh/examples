include $(TOP)/mk/targets.mk

# Set the cluster name
CLUSTER ?= kiknos-demo-1

# Set the org of new built image
ORG = vladcodaniel

# Set the tag of new built image
TAG = kiknos

# AWS Key Pair for connecting over SSH
AWS_KEY_PAIR ?= kiknos-asa

# Reference cluster required when deploying the second cluster in order to be able to take some configurations
# such as remote IP address when configuring kiknos NSE or the AWS VPC
CLUSTER_REF ?=
# Parent image for the NSE
override VPP_AGENT = ciscolabs/kiknos:latest

# Set a default forwarding plane
FORWARDING_PLANE ?= vpp

# Set a default network service for Example clients
NETWORK_SERVICE ?= hello-world

# Set whether to build the image or not
BUILD_IMAGE ?= true

# Set the mode to provision the built image. Default "push"
# one of "push" or "kind-load"
# not relevant if $BUILD_IMAGE is not true
PROVISION_MODE ?= push

# Set whether to deploy istio gateway or not
DEPLOY_ISTIO ?= true

# Create aws cluster
AWS ?= false

NSM_NAMESPACE = nsm-system
CONTAINER_REPO = networkservicemesh
CONTAINER_TAG = master
PROMETHEUS = true
METRICS_COLLECTOR_ENABLED = true
SPIRE_ENABLED = false
INSECURE = true

provide-image: k8s-universal-cnf-save

ifeq ($(PROVISION_MODE),push)
provide-image: docker-push
endif

ifeq ($(PROVISION_MODE),kind-load)
provide-image: k8s-universal-cnf-load-images
endif


docker-push:
	@docker push "$(ORG)/universal-cnf-vppagent:$(TAG)"

create-kind:
	@[[ -n `kind get clusters | grep $(CLUSTER)` ]] && echo "Cluster $(CLUSTER) already present, skipping create_kind rule" && exit 0;\
	kind create cluster --name $(CLUSTER);\
	kubectl config rename-context "kind-$(CLUSTER)" $(CLUSTER)

delete-kind:
	-@kind delete cluster --name $(CLUSTER)

create-aws:
	@[[ -n `aws eks list-clusters --output=text | grep $(CLUSTER)` ]] && echo "Cluster $(CLUSTER) already present on aws, skipping create_aws rule" && exit 0;\
	python $(TOP)/examples/ucnf-kiknos/scripts/pyaws/create_cluster.py --name $(CLUSTER) $(if $(CLUSTER_REF),--ref $(CLUSTER_REF)) --open-sg;\
	aws eks update-kubeconfig --name="$(CLUSTER)" --alias "$(CLUSTER)"

delete-aws:
	-@eksctl delete cluster --name="$(CLUSTER)"

ifeq ($(AWS),true)
create-cluster: create-aws
delete-cluster: delete-aws
else
create-cluster: create-kind
delete-cluster: delete-kind
endif

helm-init: create-cluster
	@kubectl config use-context "$(CLUSTER)"
	@pushd $(NSM_PATH); ./scripts/helm-init-wrapper.sh; popd

helm-install-nsm: helm-init
	@pushd $(NSM_PATH); ./scripts/helm-nsm-install.sh --chart nsm \
		--container_repo ${CONTAINER_REPO} \
		--container_tag ${CONTAINER_TAG} \
		--forwarding_plane ${FORWARDING_PLANE} \
		--insecure ${INSECURE} \
		--networkservice "${NETWORK_SERVICE}" \
		--enable_prometheus ${PROMETHEUS} \
		--enable_metric_collection ${METRICS_COLLECTOR_ENABLED} \
		--nsm_namespace ${NSM_NAMESPACE} \
		--spire_enabled ${SPIRE_ENABLED}; popd

ifeq ($(BUILD_IMAGE),true)
deploy-kiknos: provide-image
endif

deploy-kiknos: helm-install-nsm
	@$(TOP)/examples/ucnf-kiknos/scripts/deploy_kiknos.sh --cluster=$(CLUSTER)

deploy-istio:
	@$(TOP)/examples/ucnf-kiknos/scripts/deploy_istio.sh --cluster=$(CLUSTER)

ifeq ($(DEPLOY_ISTIO),true)
deploy-kiknos-clients: deploy-istio
ISTIO_CLIENT_OPTION=--istio-client
endif

deploy-kiknos-clients: deploy-kiknos
	@$(TOP)/examples/ucnf-kiknos/scripts/deploy_clients.sh \
		--cluster=$(CLUSTER) \
		--service-name=$(NETWORK_SERVICE) \
		$(ISTIO_CLIENT_OPTION)

deploy-kiknos-start-vpn: deploy-kiknos-clients
	@$(TOP)/examples/ucnf-kiknos/scripts/start_vpn.sh \
		--cluster=$(CLUSTER) \
		--service-name=$(NETWORK_SERVICE)

deploy-asa: #create-aws
	@$(TOP)/examples/ucnf-kiknos/scripts/deploy_asa.sh \
		--cluster=$(CLUSTER) \
		--cluster-ref=$(CLUSTER_REF) \
		--aws-key-pair=$(AWS_KEY_PAIR)

delete-context:
	-@kubectl config delete-context $(CLUSTER)

clean: delete-context delete-cluster
