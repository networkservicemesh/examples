
include $(TOP)/mk/docker-targets.mk

define GATHER_EXAMPLES
EXAMPLE_NAMES+=${NAME}
endef
$(eval $(GATHER_EXAMPLES))

define BUILD
.PHONY: $(PREFIX)-$(NAME)-build
$(PREFIX)-$(NAME)-build: $(addsuffix -build,$(addprefix ${CONTAINER_BUILD_PREFIX}-$(NAME)-,$(CONTAINERS)))
endef
$(eval $(BUILD))

define SAVE
.PHONY: $(PREFIX)-$(NAME)-save
$(PREFIX)-$(NAME)-save: $(addsuffix -save,$(addprefix ${CONTAINER_BUILD_PREFIX}-$(NAME)-,$(CONTAINERS))) $(addsuffix -save,$(addprefix ${CONTAINER_BUILD_PREFIX}-,$(AUX_CONTAINERS)))
endef
$(eval $(SAVE))

define PUSH
.PHONY: $(PREFIX)-$(NAME)-push
$(PREFIX)-$(NAME)-push: $(addsuffix -push,$(addprefix ${CONTAINER_BUILD_PREFIX}-$(NAME)-,$(CONTAINERS)))
endef
$(eval $(PUSH))

define LOAD_IMAGES
.PHONY: $(PREFIX)-$(NAME)-load-images
$(PREFIX)-$(NAME)-load-images:  $(addsuffix -load-images,$(addprefix $(CLUSTER_RULES_PREFIX)-$(NAME)-,$(CONTAINERS))) $(addsuffix -load-images,$(addprefix $(CLUSTER_RULES_PREFIX)-,$(AUX_CONTAINERS)))
endef
$(eval $(LOAD_IMAGES))

define DEPLOY
.PHONY: $(PREFIX)-$(NAME)-deploy
$(PREFIX)-$(NAME)-deploy: $(PREFIX)-$(NAME)-delete $(addsuffix -deploy,$(addprefix $(PREFIX)-$(NAME)-,$(NETWORK_SERVICES))) $(addsuffix -deploy,$(addprefix $(PREFIX)-$(NAME)-,$(PODS)))

.PHONY: $(PREFIX)-$(NAME)-%-deploy
$(PREFIX)-$(NAME)-%-deploy:
	@kubectl apply -f examples/$(NAME)/$(PREFIX)/\$$*.yaml
endef
$(eval $(DEPLOY))

define DELETE
.PHONY: $(PREFIX)-$(NAME)-delete
$(PREFIX)-$(NAME)-delete:
	@echo "Deleting examples/$(NAME)/$(PREFIX)/"
	@kubectl delete -R -f examples/$(NAME)/$(PREFIX)/ > /dev/null 2>&1 || echo "$* does not exist and thus cannot be deleted"
endef
$(eval $(DELETE))

define RUN_CHECK
.PHONY: $(PREFIX)-$(NAME)-check
$(PREFIX)-$(NAME)-check:
	@cd examples/$(NAME) && $(CHECK)
endef
$(eval $(RUN_CHECK))

define LINT
.PHONY: $(NAME)-lint
$(NAME)-lint:
	@echo "==================== START $(NAME) ===================="
	@cd examples/$(NAME) && golangci-lint run --enable-all ./... || [ -z ${FAIL_GOLINT} ] && true
	@echo "====================  END $(NAME)  ===================="
endef
$(eval $(LINT))

define DESCRIBE
.PHONY: $(NAME)-list
$(NAME)-list:
	@printf "\t %-30s %s\n" $(NAME) $(DESCRIPTION)

.PHONY: $(NAME)-describe
$(NAME)-describe:
	@if [ -x $(which consolemd) ]; then \
		consolemd examples/$(NAME)/README.md; \
	else \
		more examples/$(NAME)/README.md; \
		printf "\n \n Consider installing *consolemd* by running: \n \t pip install consolemd \n\n"; \
	fi
endef
$(eval $(DESCRIBE))
