
include $(TOP)/mk/docker-targets.mk

run-with-cleanup = $(1) && $(2) || (ret=$$?; $(2) && exit $$ret)

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
	@if [ -d "examples/$(NAME)/$(PREFIX)" ]; then \
		kubectl apply --wait -f examples/$(NAME)/$(PREFIX)/\$$*.yaml; \
	fi
endef
$(eval $(DEPLOY))

define DELETE
.PHONY: $(PREFIX)-$(NAME)-delete
$(PREFIX)-$(NAME)-delete:
	@if [ -d "examples/$(NAME)/$(PREFIX)" ]; then \
		echo "Deleting examples/$(NAME)/$(PREFIX)"; \
		kubectl delete --wait --grace-period=5 -R -f examples/$(NAME)/$(PREFIX)/ > /dev/null 2>&1 || true; \
		kubectl wait -n default --timeout=150s --for=delete --all pods \
			|| echo "$(NAME) does not exist and thus cannot be deleted"; \
	fi
endef
$(eval $(DELETE))

define RUN_CHECK
.PHONY: $(PREFIX)-$(NAME)-check
$(PREFIX)-$(NAME)-check:
	@if [ -d "examples/$(NAME)/$(PREFIX)" ]; then \
		kubectl wait -n default --timeout=150s --for condition=Ready --all pods; \
		cd examples/$(NAME) && $(CHECK); \
	fi
endef
$(eval $(RUN_CHECK))

define TEST
.PHONY: $(PREFIX)-$(NAME)-test
$(PREFIX)-$(NAME)-test:
	@echo "==================== START $(NAME) ===================="
	@$(MAKE) $(PREFIX)-$(NAME)-save
	@$(MAKE) $(PREFIX)-$(NAME)-load-images
	@$(MAKE) $(PREFIX)-$(NAME)-deploy
	@$(call run-with-cleanup, $(MAKE) $(PREFIX)-$(NAME)-check, $(MAKE) $(PREFIX)-$(NAME)-delete)
	@echo "====================  END $(NAME)  ===================="
endef
$(eval $(TEST))

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
