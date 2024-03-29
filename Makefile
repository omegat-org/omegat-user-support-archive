export PATH := $(PWD)/bin:$(PATH)

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

CPUS := $(shell sysctl -n hw.ncpu)

.PHONY: validate
validate: ## Check dumped messages for errors
validate:
	$(if $(wildcard work/*.json),,$(error Run `make dump` first))
	cd work; ls | sort -nr | xargs -n 1 -P $(CPUS) sh -c \
		'cat $$0 | json2txt | unescape | validate || echo $$0 invalid'

MSG :=

.PHONY: view
view: ## View a single dumped message as text
view:
	$(if $(MSG),,$(error Specify a message with MSG=1234))
	@<work/$(MSG).json json2txt | unescape

.PHONY: clean
clean: ## Delete MBOX, Mailman data (does not delete ML dump)
clean:
	rm -rf *.mbox mailman

MBOX := $(GROUP).mbox

.PHONY: mbox
mbox: ## Convert dump to MBOX format
mbox: $(MBOX)

$(MBOX): | work
# This task doesn't use proper dependencies for optimization purposes
	$(if $(wildcard work/*.json),,$(error Run `make dump` first))
	cd work; ls | sort -n | xargs cat | json2txt | unescape > $(PWD)/$(@)

MBOX_CLEAN := $(MBOX:.mbox=.clean.mbox)

.PHONY: mbox-clean
mbox-clean: ## Produce an MBOX cleaned by Mailman
mbox-clean: $(MBOX_CLEAN)

$(MBOX_CLEAN): $(MBOX)
	<$(<) docker run -i --rm \
		fauria/mailman  \
		/var/lib/mailman/bin/cleanarch | \
		tr -d '\r' > $(@)

mailman:
	mkdir -p $(@)/archives/{private,public}
	mkdir -p $(@)/lists

MAILMAN := docker run -it --rm \
	-v $(PWD)/mailman/archives:/var/lib/mailman/archives \
	-v $(PWD)/mailman/lists:/var/lib/mailman/lists \
	fauria/mailman

LIST_NAME := omegat-user-support
LIST_MBOX_DIR := mailman/archives/private/$(LIST_NAME).mbox
LIST_MBOX := $(LIST_MBOX_DIR)/$(LIST_NAME).mbox

.PHONY: mailman-create
mailman-create: ## Create a new mailing list
mailman-create: $(LIST_MBOX_DIR)

ARCHIVE_HOST := example.com

$(LIST_MBOX_DIR): | mailman
	$(MAILMAN) /var/lib/mailman/bin/newlist -q -a \
		--urlhost=$(ARCHIVE_HOST) \
		$(LIST_NAME) \
		owner@$(ARCHIVE_HOST) \
		example

$(LIST_MBOX): $(MBOX_CLEAN) | $(LIST_MBOX_DIR)
	cp $(<) $(@)

LIST_INDEX := mailman/archives/private/$(LIST_NAME)/index.html

.PHONY: mailman-archive
mailman-archive: ## Import MBOX into Mailman and build archives
mailman-archive: $(LIST_INDEX)

$(LIST_INDEX): | $(LIST_MBOX)
	$(MAILMAN) /var/lib/mailman/bin/arch --wipe $(LIST_NAME)

HOMEPAGE := https://github.com/omegat-org/omegat-user-support-archive

.PHONY: mailman-fixup
mailman-fixup: ## Post-process Mailman archive
mailman-fixup: export LC_ALL := C
mailman-fixup: $(LIST_INDEX)
	find $$(dirname $(LIST_INDEX)) -type f -print0 | xargs -0 -P $(CPUS) \
		sed -i '' 's|http://$(ARCHIVE_HOST)/cgi-bin/mailman/listinfo/$(LIST_NAME)|$(HOMEPAGE)|g'

USER :=
HOST := web.sourceforge.net
DEPLOY_TARGET := /home/project-web/omegat/htdocs
DRY_RUN ?= -n

.PHONY: deploy
deploy: ## Deploy Mailman archive to remote server
deploy: $(LIST_INDEX)
	$(if $(USER),,$(error Specify user with USER=))
	$(if $(DRY_RUN),$(info Dry run. Specify DRY_RUN= to actually deploy.))
	cd $$(dirname $(LIST_INDEX)); \
		rsync -av --size-only $(DRY_RUN) -e ssh . $(USER)@$(HOST):$(DEPLOY_TARGET)/user-support-archive

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
	$(info Specify the group name with GROUP=foo (default: $(GROUP)))
	$(info )
	$(info Available targets:)
	@awk -F ':.*?## *' '/^[^\t].+?:.*?##/ \
         {printf "  %-24s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
