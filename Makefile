SHELL := /bin/bash

APP := hostsctl
BIN := bin/hostsctl.zsh
VERSION ?= $(shell grep -E '^VERSION=' $(BIN) | cut -d\" -f2)

.PHONY: help
help:
	@echo "make lint | test | release | tag VERSION=X.Y.Z"

.PHONY: lint
lint:
	@zsh -n $(BIN)
	
.PHONY: test
test:
	@bats -r tests

.PHONY: tag
tag:
	@test -n "$(VERSION)" || (echo "VERSION not found"; exit 1)
	@git add -A && git commit -m "release: v$(VERSION)" || true
	@git tag -a "v$(VERSION)" -m "v$(VERSION)"
	@git push --follow-tags

.PHONY: release
release: lint test
	@echo "Cut a GitHub release for v$(VERSION)"

# Add a make target to run tasks (lint, format, test)
.PHONY: all
all: lint test
