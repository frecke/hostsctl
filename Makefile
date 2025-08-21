SHELL := /bin/bash

APP := hostsctl
BIN := bin/hostsctl.zsh
VERSION ?= $(shell grep -E '^VERSION=' $(BIN) | cut -d\" -f2)

.PHONY: help
help:
	@echo "make lint | test | format | release | tag VERSION=X.Y.Z"

.PHONY: lint
lint:
	@shellcheck -x $(BIN)
	@shfmt -d -i 2 -ci -sr .

.PHONY: format
format:
	@shfmt -w -i 2 -ci -sr .

.PHONY: test
test:
	@bats -r test

.PHONY: tag
tag:
	@test -n "$(VERSION)" || (echo "VERSION not found"; exit 1)
	@git add -A && git commit -m "release: v$(VERSION)" || true
	@git tag -a "v$(VERSION)" -m "v$(VERSION)"
	@git push --follow-tags

.PHONY: release
release: lint test
	@echo "Cut a GitHub release for v$(VERSION)"
ß