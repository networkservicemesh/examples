EXAMPLES = $(dir $(wildcard ./examples/*/.))

define include-example
# Clear config variables before including the next example.
# The name defaults to the folder name
  NAME = $1
  DESCRIPTION = "No description set"
  CONTAINERS =
  AUX_CONTAINERS =
  NETWORK_SERVICES =
  PODS =
  CHECK =
  FAIL_GOLINT = 1

  include $1/Makefile
endef

$(foreach example,$(EXAMPLES),$(eval $(call include-example,$(example))))