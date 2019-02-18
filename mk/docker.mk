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

ORG=networkservicemesh

.PHONY: docker-%-kill
docker-%-kill:
	@echo "Killing $*... $$(cat /tmp/container.$* | cut -c1-12)"
	@docker container ls | grep $$(cat /tmp/container.$* | cut -c1-12) > /dev/null && xargs docker kill < /tmp/container.$* || echo "$* already killed"

.PHONY: docker-%-logs
docker-%-logs:
	@echo "Showing nsmd logs..."
	@xargs docker logs < /tmp/container.$*

.PHONY: docker-push-%
docker-%-push: docker-login docker-%-build
	docker tag ${ORG}/$*:${COMMIT} ${ORG}/$*:${TAG}
	docker tag ${ORG}/$*:${COMMIT} ${ORG}/$*:${BUILD_TAG}
	docker push ${ORG}/$*

.PHONY: docker-build
docker-build: $(addsuffix -build,$(addprefix k8s-,$(EXAMPLE_NAMES)))
