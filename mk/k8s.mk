# Copyright (c) 2018 Cisco and/or its affiliates.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at:
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

K8S_CONF_DIR = k8s/conf

CLUSTER_CONFIG = cluster crd
DEPLOY_INFRA = infra

# All of the rules that use vagrant are intentionally written in such a way
# That you could set the CLUSTER_RULES_PREFIX different and introduce
# a new platform to run on with k8s by adding a new include ${method}.mk
# and setting CLUSTER_RULES_PREFIX to a different value
ifeq ($(CLUSTER_RULES_PREFIX),)
CLUSTER_RULES_PREFIX := vagrant
endif
include mk/vagrant.mk

# .null.mk allows you to skip the vagrant machinery with:
# export CLUSTER_RULES_PREFIX=null
# before running make
include mk/null.mk

# Pull in docker targets
CONTAINER_BUILD_PREFIX = docker

.PHONY: k8s-infra-deploy
k8s-infra-deploy: $(addsuffix -config,$(addprefix k8s-,$(DEPLOY_INFRA)))

.PHONY: k8s-infra-delete
k8s-infra-delete: $(addsuffix -deconfig,$(addprefix k8s-,$(DEPLOY_INFRA)))

.PHONY: k8s-%-deploy
k8s-%-deploy:  k8s-start k8s-config k8s-%-delete k8s-%-load-images
	@until ! $$(kubectl get pods | grep -q ^$* ); do echo "Wait for $* to terminate"; sleep 1; done
	@sed "s;\(image:[ \t]*networkservicemesh/[^:]*\).*;\1$${COMMIT/$${COMMIT}/:$${COMMIT}};" ${K8S_CONF_DIR}/$*/*.yaml | kubectl apply -f -

.PHONY: k8s-%-delete
k8s-%-delete:
	@echo "Deleting ${K8S_CONF_DIR}/$*/*.yaml"
	@kubectl delete -R -f ${K8S_CONF_DIR}/$* > /dev/null 2>&1 || echo "$* does not exist and thus cannot be deleted"

.PHONY: k8s-%-config
k8s-%-config:
	@kubectl apply -R -f ${K8S_CONF_DIR}/$*

.PHONY: k8s-%-deconfig
k8s-%-deconfig:
	@kubectl delete -R -f ${K8S_CONF_DIR}/$*

.PHONY: k8s-config
k8s-config: $(addsuffix -config,$(addprefix k8s-,$(CLUSTER_CONFIG)))
	@kubectl label --overwrite --all=true nodes app=nsmd-ds

.PHONY: k8s-deconfig
k8s-deconfig: $(addsuffix -deconfig,$(addprefix k8s-,$(CLUSTER_CONFIG)))

.PHONY: k8s-start
k8s-start: $(CLUSTER_RULES_PREFIX)-start

.PHONY: k8s-restart
k8s-restart: $(CLUSTER_RULES_PREFIX)-restart

.PHONY: k8s-build
k8s-build: $(addsuffix -build,$(addprefix k8s-,$(DEPLOYS)))

.PHONY: k8s-save
k8s-save: $(addsuffix -save,$(addprefix k8s-,$(DEPLOYS)))
