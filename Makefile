SHELL := bash

bold := $(shell tput bold)
norm := $(shell tput sgr0)

GOLANG_VERSION := 1.16
APP_NAME := whmcs-inbound-piped

# gh-actions shim
ifdef GITHUB_REPOSITORY
	REPO_NAME := $(GITHUB_REPOSITORY)
endif

ifdef GITHUB_REF
ifneq (,$(findstring refs/heads/,$(GITHUB_REF)))
	GIT_BRANCH := $(GITHUB_REF:refs/heads/%=%)
else ifneq (,$(findstring refs/tags/,$(GITHUB_REF)))
	TAG_NAME := $(GITHUB_REF:refs/tags/%=%)
endif
endif

REPO_NAME ?= $(notdir $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..))/$(shell basename '$(PWD)')


$(info [REPO_NAME: $(REPO_NAME)])
$(info [GIT_BRANCH: $(GIT_BRANCH)])
$(info [TAG_NAME: $(TAG_NAME)])


.PHONY: all
all:


.PHONY: tidy
tidy:
	go fmt
	go mod tidy


.PHONY: build
build:
	go build
	docker build -t s-nail docker/s-nail


.PHONY: crossbuild
crossbuild: build-darwin build-linux build-windows


.PHONY: build-darwin
build-darwin:
	mkdir -p dist/darwin/amd64
	docker run --rm \
		-v "$(PWD):/app" \
		-w "/app" \
		-e "GOOS=darwin" \
		-e "GOARCH=amd64" \
		-e "CGO_ENABLED=0" \
		--entrypoint sh \
		'golang:$(GOLANG_VERSION)-alpine' \
		-c "go get -d -v && go build -a -v -o dist/darwin/amd64/$(APP_NAME)" \
		2> /dev/stdout | while IFS= read -r line; do printf '[%s] %s\n' "$@" "$${line}"; done; [ "$${PIPESTATUS[0]}" -le "0" ] || exit "$${PIPESTATUS[0]}"


.PHONY: build-linux
build-linux:
	mkdir -p dist/linux/amd64
	docker run --rm \
		-v "$(PWD):/app" \
		-w "/app" \
		-e "GOOS=linux" \
		-e "GOARCH=amd64" \
		-e "CGO_ENABLED=0" \
		--entrypoint sh \
		'golang:$(GOLANG_VERSION)-alpine' \
		-c "go get -d -v && go build -a -v -o dist/linux/amd64/$(APP_NAME)" \
		2> /dev/stdout | while IFS= read -r line; do printf '[%s] %s\n' "$@" "$${line}"; done; [ "$${PIPESTATUS[0]}" -le "0" ] || exit "$${PIPESTATUS[0]}"


.PHONY: build-windows
build-windows:
	mkdir -p dist/windows/amd64
	docker run --rm \
		-v "$(PWD):/app" \
		-w "/app" \
		-e "GOOS=windows" \
		-e "GOARCH=amd64" \
		-e "CGO_ENABLED=0" \
		--entrypoint sh \
		'golang:$(GOLANG_VERSION)-alpine' \
		-c "go get -d -v && go build -a -v -o dist/windows/amd64/$(APP_NAME)" \
		2> /dev/stdout | while IFS= read -r line; do printf '[%s] %s\n' "$@" "$${line}"; done; [ "$${PIPESTATUS[0]}" -le "0" ] || exit "$${PIPESTATUS[0]}"


.PHONY: package
package: dist/*/*
	for file in $^ ; do \
		pushd "$${file}" ; \
		zip '$(APP_NAME).zip' '$(APP_NAME)' ; \
		popd ; \
	done
