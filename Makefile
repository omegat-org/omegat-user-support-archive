SUBMODULES := YahooGroups-Archiver

.PHONY: submodules
submodules: ## Fetch submodules
submodules: | $(addsuffix /.git,$(SUBMODULES))

$(addsuffix /.git,$(SUBMODULES)):
	git submodule init
	git submodule update

.PHONY: help
help: ## Show this help text
	$(info usage: make [target])
	$(info )
	$(info Available targets:)
	@awk -F ':.*?## *' '/^[^\t].+?:.*?##/ \
         {printf "  %-24s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
