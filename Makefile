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

TOP := $(CURDIR)

# We want to use bash
SHELL:=/bin/bash

# Default target, no other targets should be before default
.PHONY: default
default: all

NSM_PATH?=${TOP}/../networkservicemesh
CLUSTER_RULES_PREFIX?=vagrant
PREFIX?=k8s
CONTAINER_BUILD_PREFIX?=docker

include examples/examples.mk

.PHONY: build-all
build-all: $(addsuffix -build,$(addprefix ${PREFIX}-,$(EXAMPLE_NAMES)))
	@echo "Built the following examples: ${EXAMPLE_NAMES}"

.PHONY: save-all
save-all: $(addsuffix -save,$(addprefix ${PREFIX}-,$(EXAMPLE_NAMES)))
	@echo "Saved the following examples: ${EXAMPLE_NAMES}"

.PHONY: lint-all
lint-all: $(addsuffix -lint,$(EXAMPLE_NAMES))

%:
	@cd ${NSM_PATH} && make $*
