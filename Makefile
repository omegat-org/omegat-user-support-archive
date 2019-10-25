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
# ...but modified to be compatible with Mailman's `cleanarch` script:
# https://github.com/python/cpython/blob/c80955cdee60c2688819a99a4c54252d77998263/Lib/mailbox.py#L2127
JSON_TO_TXT := jq -r '.ygData|["From "+(.from|ltrimstr(" ")|rtrimstr(" ")|split(" ")|.[-1]|ltrimstr("&lt;")|rtrimstr("&gt;"))+" "+(.postDate|tonumber|gmtime|strftime("%a %b %d %H:%M:%S %Y")),.rawEmail]|.[]'

UNESCAPE := recode html..utf-8

MSG :=

.PHONY: view
view: ## View a single dumped message as text
view:
	$(if $(MSG),,$(error Specify a message with MSG=1234))
	@<work/$(MSG).json $(JSON_TO_TXT) | $(UNESCAPE)

MBOX := $(GROUP).mbox

.PHONY: mbox
mbox: ## Convert dump to MBOX format
mbox: $(MBOX)

$(MBOX): | work
# This task doesn't use proper dependencies for optimization purposes
	$(if $(wildcard work/*.json),,$(error Run `make dump` first))
	cd work; ls | sort -nr | xargs cat | $(JSON_TO_TXT) | $(UNESCAPE) > $(PWD)/$(@)

MBOX_CLEAN := $(MBOX:.mbox=.clean.mbox)

.PHONY: mbox-clean
mbox-clean: ## Produce an MBOX cleaned by Mailman
mbox-clean: $(MBOX_CLEAN)

$(MBOX_CLEAN): $(MBOX)
	docker run -t --rm \
		-v $(PWD):/work \
		fauria/mailman  \
		sh -c '</work/OmegaT.mbox /var/lib/mailman/bin/cleanarch -q' > OmegaT.clean.mbox

.PHONY: proxy-start
proxy-start: ## Start reverse proxy for Mailman
proxy-start:
	ergo run -domain .wtf &

.PHONY: proxy-stop
proxy-stop: ## Stop reverse proxy for Mailman
proxy-stop:
	killall ergo

mailman:
# `chown` is recommended by container author, but caused errors for me
	mkdir -p $(@)/archives/{private,public}
	mkdir -p $(@)/lists
#	sudo chown -R 0:38 $(@)/{archives,lists}
#	sudo chown 33 $(@)/archives/private
	mkdir -p $(@)/log/{apache2,exim4,mailman}
#	sudo chown 0:4 $(@)/log/apache2
#	sudo chown 105:4 $(@)/log/exim4
#	sudo chown 0:38 $(@)/log/mailman

.PHONY: mailman-start
mailman-start: ## Start Mailman
mailman-start: | mailman
	$(info Set up mailing list at http://myarchive.wtf/mailman/listinfo)
	docker run -it --rm \
		-p '2222:80' \
		-h myarchive.wtf \
		-e DEBUG_CONTAINER=true \
		-e URL_FQDN=myarchive.wtf \
		-e EMAIL_FQDN=myarchive.wtf \
		-v $(PWD)/mailman/archives:/var/lib/mailman/archives \
		-v $(PWD)/mailman/lists:/var/lib/mailman/lists \
		-v $(PWD)/mailman/keys:/etc/exim4/tls.d \
		-v $(PWD)/mailman/log/apache2:/var/log/apache2 \
		-v $(PWD)/mailman/log/exim4:/var/log/exim4 \
		-v $(PWD)/mailman/log/mailman:/var/log/mailman \
		-v $(PWD):/work \
		fauria/mailman

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
