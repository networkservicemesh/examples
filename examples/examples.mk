EXAMPLES = $(dir $(wildcard ./examples/*/.))

define include-example
  include $1/Makefile
endef

$(foreach example,$(EXAMPLES),$(eval $(call include-example,$(example))))