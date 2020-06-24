# Parent image for the NSE
VPP_AGENT = ciscolabs/kiknos:latest

# Set the cluster name
CLUSTER ?= kiknos-demo-1

# Configure examples
NAME = ucnf-kiknos
CONTAINERS = vppagent
KIND_CLUSTER_NAME = $(CLUSTER)

include $(TOP)/mk/targets.mk

# AWS Key Pair for connecting over SSH
AWS_KEY_PAIR ?= kiknos-asa

# Reference cluster required when deploying the second cluster in order to be able to take some configurations
# such as remote IP address when configuring kiknos NSE or the AWS VPC
CLUSTER_REF ?=

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

# IP for the remote ASA subnet (without the mask, ex: 192.168.254.0)
SUBNET_IP = 192.168.254.0

NSM_NAMESPACE = nsm-system
CONTAINER_REPO = networkservicemesh
CONTAINER_TAG = master
PROMETHEUS = true
METRICS_COLLECTOR_ENABLED = true
SPIRE_ENABLED = false
INSECURE = true

.PHONY: docker-push load-images provide-image provide-image provide-image create-kind delete-kind create-aws delete-aws \
		create-cluster delete-cluster create-cluster delete-cluster helm-init helm-install-nsm deploy-kiknos deploy-kiknos \
		deploy-istio deploy-kiknos-clients deploy-kiknos-clients deploy-kiknos-start-vpn deploy-asa delete-context clean

docker-push:
	@docker push "$(ORG)/ucnf-kiknos-vppagent:$(TAG)"

load-images:
	kind load docker-image "$(ORG)/ucnf-kiknos-vppagent:$(TAG)" --name=$(CLUSTER)

provide-image: k8s-ucnf-kiknos-save

ifeq ($(PROVISION_MODE),push)
provide-image: docker-push
endif

ifeq ($(PROVISION_MODE),kind-load)
provide-image: load-images
endif

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
	@$(TOP)/examples/ucnf-kiknos/scripts/deploy_kiknos.sh --cluster=$(CLUSTER) \
		--subnet-ip=$(SUBNET_IP) \
		--org=$(ORG) \
		--tag=$(TAG)
		$(if $(CLUSTER_REF),--cluster-ref=$(CLUSTER_REF))

deploy-istio: deploy-kiknos
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

ifeq ($(DEPLOY_ISTIO),true)
deploy-asa: deploy-istio
endif

deploy-asa: deploy-kiknos
	@$(TOP)/examples/ucnf-kiknos/scripts/deploy_asa.sh \
		--cluster-ref=$(CLUSTER) \
		--subnet-ip=$(SUBNET_IP) \
		--aws-key-pair=$(AWS_KEY_PAIR)


delete-context:
	-@kubectl config delete-context $(CLUSTER)

clean: delete-context delete-cluster
