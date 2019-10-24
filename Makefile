GROUP := OmegaT

SUBMODULES := YahooGroups-Archiver
PYENV := $(PWD)/.env
ARCHIVE_GROUP := $(PYENV)/bin/python $(PWD)/YahooGroups-Archiver/archive_group.py

work:
	mkdir -p $(@)

# Workaround for archive script insisting on outputting to sibling directory
TARGET_LINK := YahooGroups-Archiver/$(GROUP)
$(TARGET_LINK):
	ln -s ../work $(@)

.PHONY: dump
dump: ## Download raw JSON for group
dump: submodules $(TARGET_LINK) | $(PYENV) work
	$(ARCHIVE_GROUP) $(GROUP)

# Date format for MBOX format (RFC 5322) taken from coreutils `date`:
# https://github.com/coreutils/coreutils/blob/c1e19656c8aa7a1e81416e024af0cdfe652df7b2/src/date.c#L76
JSON_TO_TXT := jq -r '.ygData|["From "+(.from|split(" ")|.[-1])+" "+(.postDate|tonumber|gmtime|strftime("%a, %d %b %Y %H:%M:%S %z")),.rawEmail]|.[]'

UNESCAPE := recode html..utf-8

MBOX := $(GROUP).mbox

.PHONY: mbox
mbox: ## Convert dump to MBOX format
mbox: $(MBOX)

$(MBOX): | work
# This task doesn't use proper dependencies for optimization purposes
	$(if $(wildcard work/*.json),,$(error Run `make dump` first))
	cd work; ls | sort -nr | xargs cat | $(JSON_TO_TXT) | $(UNESCAPE) > $(PWD)/$(@)

$(PYENV):
	virtualenv $(@)
	$(@)/bin/pip install requests

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
