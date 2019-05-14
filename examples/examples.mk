EXAMPLES = $(dir $(wildcard ./examples/*/.))

define include-example
# Clear config variables before including the next example.
# The name defaults to the folder name
  NAME = $1
  CONTAINERS =
  AUX_CONTAINERS =
  PODS =
  CHECK =

  include $1/Makefile
endef

$(foreach example,$(EXAMPLES),$(eval $(call include-example,$(example))))