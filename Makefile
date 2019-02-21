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

# Pull in k8s targets
include mk/k8s.mk
include mk/skydive.mk
include mk/jaeger.mk

GOPATH?=$(shell go env GOPATH 2>/dev/null)
GOCMD=go
GOFMT=${GOCMD} fmt
GOGET=${GOCMD} get
GOGENERATE=${GOCMD} generate
GOINSTALL=${GOCMD} install
GOTEST=${GOCMD} test
GOVET=${GOCMD} vet --all

# Export some of the above variables so they persist for the shell scripts
# which are run from the Makefiles
export GOPATH \
       GOCMD \
       GOFMT \
       GOGET \
       GOGENERATE \
       GOINSTALL \
       GOTEST \
       GOVET \
       EXAMPLE_NAMES



include examples/examples.mk
include mk/docker.mk

.PHONY: all check verify
all: check verify docker-build list-examples

.PHONY: check
check:
	@shellcheck `find . -name "*.sh" -not -path "*vendor/*"`

.PHONY: list-examples
list-examples:
	@echo "Built the following examples: ${EXAMPLE_NAMES}"

.PHONY: format deps generate install test test-race vet
#
# The following targets are meant to be run when working with the code locally.
#
format:
	@${GOFMT} ./...

deps:
	@${GOGET} -u github.com/golang/protobuf/protoc-gen-go

generate:
	@${GOGENERATE} ./...

install:
	@${GOINSTALL} ./...

test:
	@${GOTEST} ./... -cover

test-race:
	@${GOTEST} -race ./... -cover

vet:
	@${GOVET} ./...
