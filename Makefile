#!/usr/bin/make
PYTHON := /usr/bin/python3
export PYTHONPATH := hooks

CHARM_STORE_URL := cs:~ivoks/lldpd
REPO := git+ssh://git.launchpad.net/lldpd-charm

SHELL := /bin/bash
export SHELLOPTS:=errexit:pipefail


virtualenv:
	virtualenv -p $(PYTHON) .venv
	.venv/bin/pip install flake8 nose mock six

lint: virtualenv
	.venv/bin/flake8 --exclude hooks/charmhelpers hooks tests/10-tests
	@charm proof

bin/charm_helpers_sync.py:
	@mkdir -p bin
	@curl -o bin/charm_helpers_sync.py https://raw.githubusercontent.com/juju/charm-helpers/master/tools/charm_helpers_sync/charm_helpers_sync.py

sync: bin/charm_helpers_sync.py
	@$(PYTHON) bin/charm_helpers_sync.py -c charm-helpers-hooks.yaml
	@$(PYTHON) bin/charm_helpers_sync.py -c charm-helpers-tests.yaml

test:
	@echo Starting Amulet tests...
	# coreycb note: The -v should only be temporary until Amulet sends
	# raise_status() messages to stderr:
	#   https://bugs.launchpad.net/amulet/+bug/1320357
	@juju test -v -p AMULET_HTTP_PROXY --timeout 900 \
	00-setup 10-tests

publish-stable:
	@if [ -n "`git status --porcelain`" ]; then \
	    echo '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'; \
	    echo '!!! There are uncommitted changes !!!'; \
	    echo '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'; \
	    false; \
	fi
	git clean -fdx
	export rev=`charm push . $(CHARM_STORE_URL) 2>&1 \
		| tee /dev/tty | grep url: | cut -f 2 -d ' '` \
	&& git tag -f -m "$$rev" `echo $$rev | tr -s '~:/' -` \
	&& git push --tags $(REPO) \
	&& charm publish -c stable $$rev
