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

ORG=networkservicemesh

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

DOCKERBUILD=docker build ${HTTPBUILD} ${HTTPSBUILD}

define generate-docker-targets
.PHONY: docker-$1-$2-build
docker-$1-$2-build:
	@${DOCKERBUILD} -t ${ORG}/$1-$2 -f examples/$1/$2/Dockerfile .
	@if [ "x${COMMIT}" != "x" ] ; then \
		docker tag ${ORG}/$1-$2 ${ORG}/$1-$2:${COMMIT} ;\
	fi

.PHONY: docker-%-save
docker-$1-$2-save: docker-$1-$2-build
	@echo "Saving $1-$2"
	@mkdir -p ${NSM_PATH}/scripts/vagrant/images/
	@docker save -o ${NSM_PATH}/scripts/vagrant/images/$1-$2.tar ${ORG}/$1-$2
endef

$(foreach container,$(CONTAINERS),$(eval $(call generate-docker-targets,$(NAME),$(container))))
