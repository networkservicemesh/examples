# Copyright 2019 VMware, Inc.
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at:
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

ORG ?= networkservicemesh
TAG ?= latest

# Setup proxies for docker build
ifeq ($(HTTP_PROXY),)
HTTPBUILD=
else
HTTPBUILD=--build-arg HTTP_PROXY=$(HTTP_PROXY)
endif
ifeq ($(HTTPS_PROXY),)
HTTPSBUILD=
else
HTTPSBUILD=--build-arg HTTPS_PROXY=$(HTTPS_PROXY)
endif

# Go 1.14 which we use to build our code in golang:alpine docker images
# aparenlty has some issues, which are fixed by setting these flags
# as described here:
# https://github.com/docker-library/golang/issues/320
#
DOCKERGOFIX=--ulimit memlock=-1

DOCKERBUILD=docker build --network="host" --build-arg VPP_AGENT=$(VPP_AGENT) ${HTTPBUILD} ${HTTPSBUILD} ${DOCKERGOFIX}

define generate-docker-targets
.PHONY: docker-$1-$2-build
docker-$1-$2-build:
	@${DOCKERBUILD} -t ${ORG}/$1-$2 -f examples/$1/$2/Dockerfile .
	@if [ "x${TAG}" != "x" ] ; then \
		docker tag ${ORG}/$1-$2 ${ORG}/$1-$2:${TAG} ;\
	fi

.PHONY: docker-%-save
docker-$1-$2-save: docker-$1-$2-build
	@echo "Saving $1-$2"
	@mkdir -p ${NSM_PATH}/build/images/
	@docker save -o ${NSM_PATH}/build/images/$1-$2.tar ${ORG}/$1-$2

.PHONY: docker-%-push
docker-$1-$2-push: docker-$1-$2-build
	@echo "Pushing $1-$2"
	@echo "${DOCKER_PASSWORD}" | docker login -u "${DOCKER_USERNAME}" --password-stdin
	@docker push ${ORG}/$1-$2:${TAG}
endef

$(foreach container,$(CONTAINERS),$(eval $(call generate-docker-targets,$(NAME),$(container))))
