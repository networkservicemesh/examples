PREFIX = k8s

include $(TOP)/mk/docker.mk

.PHONY: ${PREFIX}-${NAME}-build
${PREFIX}-${NAME}-build: $(addsuffix -build,$(addprefix ${CONTAINER_BUILD_PREFIX}-$(NAME)-,$(CONTAINERS)))

.PHONY: ${PREFIX}-${NAME}-save
${PREFIX}-${NAME}-save: $(addsuffix -save,$(addprefix ${CONTAINER_BUILD_PREFIX}-$(NAME)-,$(CONTAINERS)))

.PHONY: ${PREFIX}-${NAME}-load-images
${PREFIX}-${NAME}-load-images:  $(addsuffix -load-images,$(addprefix $(CLUSTER_RULES_PREFIX)-${NAME}-,$(CONTAINERS)))

.PHONY: ${PREFIX}-${NAME}-deploy
${PREFIX}-${NAME}-deploy: ${PREFIX}-${NAME}-delete ${PREFIX}-${NAME}-load-images $(addsuffix -deploy,$(addprefix $(PREFIX)-${NAME}-,$(PODS)))

.PHONY: ${PREFIX}-${NAME}-%-deploy
${PREFIX}-${NAME}-%-deploy:
	@until ! $$(kubectl get pods | grep -q ^$* ); do echo "Wait for $* to terminate"; sleep 1; done
	@sed "s;\(image:[ \t]*networkservicemesh/[^:]*\).*;\1$${COMMIT/$${COMMIT}/:$${COMMIT}};" examples/${NAME}/${PREFIX}/$*.yaml | kubectl apply -f -

.PHONY: ${PREFIX}-${NAME}-delete
${PREFIX}-${NAME}-delete:
	@echo "Deleting examples/${NAME}/${PREFIX}/"
	@kubectl delete -R -f examples/${NAME}/${PREFIX}/ > /dev/null 2>&1 || echo "$* does not exist and thus cannot be deleted"

.PHONY: ${PREFIX}-${NAME}-check
${PREFIX}-${NAME}-check:
	@cd examples/${NAME} && ${CHECK}
