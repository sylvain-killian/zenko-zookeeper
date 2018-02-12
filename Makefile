CHARTS_DIR = charts
DOCKERFILES_DIR = images

DOCKERFILES = $(wildcard $(DOCKERFILES_DIR)/*)
DOCKER_IMAGES = $(foreach docker,$(DOCKERFILES),$(notdir $(docker)))

DOCKER_REGISTRY ?=
ifneq ($(DOCKER_REGISTRY),)
# Ensure there is '/' at the end of Docker regsitry
DOCKER_REGISTRY := $(DOCKER_REGISTRY:/=)/
endif

# Remove the 'v' of git tag (v0.0.2 -> 0.0.2)
# This variable is lazy evaluated
DOCKER_TAG = $(or $(CURRENT_VERSION:v%=%),latest)

BUILD_DIR = build
BUILD_ENV_FILE ?= $(BUILD_DIR)/env.sh
RELEASE_PATCH_FILE = $(BUILD_DIR)/release.patch

COMMIT_fix := patch
COMMIT_feat := minor

DOCKER_CHECK_BUILD_TARGETS := $(foreach image,${DOCKER_IMAGES},docker-check-build/$(image))
DOCKER_OLD_TAG_TARGETS := $(foreach image,${DOCKER_IMAGES},docker-old-tag/$(image))
DOCKER_CHECK_TARGETS := $(foreach image,${DOCKER_IMAGES},docker-check/$(image))
DOCKER_BUILD_TARGETS := $(foreach image,${DOCKER_IMAGES},docker-build/$(image))
DOCKER_PUSH_TARGETS := $(foreach image,${DOCKER_IMAGES},docker-push/$(image))

define target_to_image
    IMAGE := $$(lastword $$(subst /, ,$(1)))
    DOCKER_DIR := $(DOCKERFILES_DIR)/$$(IMAGE)
endef

define image_to_tag
    IMAGE_TAG := $(1):$(DOCKER_TAG)
    ifneq ($(DOCKER_REGISTRY),)
        IMAGE_TAG := $(DOCKER_REGISTRY)$$(IMAGE_TAG)
    endif
endef

define sed_helm_image
    ifneq ($$(DOCKER_TAG),latest)
        ifeq ($$($(1)_ALREADY_BUILT),0)
            $$(shell sed -e "s/\(ImageTag:\).*/\1 $$(DOCKER_TAG)/" -i $$(VALUES_YAML))
        endif
    endif
endef

define release_vars
    GIT_DIRTY ?= $$(shell git diff --quiet HEAD || echo 1)
    GIT_DIRTY := $$(GIT_DIRTY)
    ifeq ($$(RELEASE),1)
      COMMIT_PARSED := $$(shell git log -1 --pretty=%B|conventional-commits-parser)
      COMMIT_TYPE ?= $$(shell echo '$$(COMMIT_PARSED)'| jq -r '.[0].type')
      ifneq ($$(COMMIT_$$(COMMIT_TYPE)),)
        CURRENT_VERSION := v$$(shell semver $$(PREV_VERSION) -i $$(COMMIT_$$(COMMIT_TYPE)))
      endif
    endif
endef

define git_dirty_check
    ifeq ($$(GIT_DIRTY),1)
        $$(error Cannot release with an unclean history (or git not installed))
    endif
endef

RUN_DOCKER ?= 1
DOCKER_RELENG ?= zenko/zenko-releng:0.0.4
CONTAINERIZED_TARGETS := release \
			 helm-package \
			 publish \
			 $(DOCKER_CHECK_TARGETS) \
			 $(DOCKER_CHECK_BUILD_TARGETS) \
			 $(DOCKER_BUILD_TARGETS) \
			 $(DOCKER_PUSH_TARGETS)


.PHONY: release $(BUILD_ENV_FILE) docker-build docker-push clean

clean:
	rm -rf $(BUILD_ENV_FILE)

$(BUILD_DIR):
	mkdir $@

docker-check-build: $(DOCKER_CHECK_BUILD_TARGETS)
docker-build: $(DOCKER_BUILD_TARGETS)
docker-push: $(DOCKER_PUSH_TARGETS)

build-all: docker-check-build helm-package

ifeq ($(RUN_DOCKER),1)

$(CONTAINERIZED_TARGETS):
	@docker run --rm \
	-v $(shell pwd):/workdir \
	-v /var/run/docker.sock:/var/run/docker.sock \
	-v ${HOME}/.gitconfig:/.gitconfig \
	-u $(shell id -u):$(shell id -g) \
	$(foreach gid,$(shell id -G),--group-add $(gid)) \
	$(DOCKER_RELENG) \
	make $@ $(MAKEFLAGS)

else

ifeq ($(RELEASE),1)
    VERSION_NO_DIRTY ?= $(shell git describe --tags)
    CURRENT_VERSION ?= $(shell git describe --tags --dirty)
    CURRENT_VERSION := $(CURRENT_VERSION)

    PREV_VERSION ?= $(lastword $(filter-out $(VERSION_NO_DIRTY),$(shell git tag -l v* | tail -n2)))
    PREV_VERSION := $(PREV_VERSION)
endif


CHARTS_LIST = $(shell find $(CHARTS_DIR) -mindepth 1 -maxdepth 1 -type d)
VALUES_YAML ?= $(firstword $(CHARTS_LIST))/values.yaml

$(DOCKER_CHECK_TARGETS):
	$(eval $(call target_to_image,$@))
	$(eval $(call image_to_tag,$(IMAGE)))
	$(eval $(IMAGE)_GIT_REV=$(shell git log -n 1 --pretty=format:%H -- $(DOCKERFILES_DIR)))
	$(eval $(IMAGE)_ALREADY_BUILT=$(shell git tag $(PREV_VERSION) -l --contains $($(IMAGE)_GIT_REV)|wc -l))

$(DOCKER_CHECK_BUILD_TARGETS): $(DOCKER_CHECK_TARGETS)
	$(eval $(call target_to_image,$@))
	$(eval $(call image_to_tag,$(IMAGE)))
	@export IMAGE_BUILT=$($(IMAGE)_ALREADY_BUILT); \
	if [ 0 -eq "$${IMAGE_BUILT}" ]; then \
	    echo "Image '$(IMAGE)' must be built"; \
	    $(MAKE) docker-build/$(IMAGE); \
	else \
	    echo "Image '$(IMAGE)' already built"; \
	fi

${DOCKER_BUILD_TARGETS}:
	$(eval $(call target_to_image,$@))
	$(eval $(call image_to_tag,$(IMAGE)))
	$(eval $(call release_vars))
	@echo "=================================================="
	@echo "Building ${IMAGE} (Tagged: ${IMAGE_TAG})"
	@echo "=================================================="
	cd ${DOCKER_DIR}; \
	DOCKER_REGISTRY=$(DOCKER_REGISTRY) \
	DOCKER_TAG=$(DOCKER_TAG) \
	./build.sh

${DOCKER_PUSH_TARGETS}:
	$(eval $(call target_to_image,$@))
	$(eval $(call image_to_tag,$(IMAGE)))
	docker push ${IMAGE_TAG}

release: $(BUILD_ENV_FILE)

$(BUILD_ENV_FILE): $(DOCKER_CHECK_TARGETS) | ${BUILD_DIR}
	$(eval $(call release_vars))
	$(eval $(call git_dirty_check))
	$(foreach image,$(DOCKER_IMAGES),$(eval $(call sed_helm_image,$(image))))
	@for CHART in $(CHARTS_LIST); do \
	    sed -e "s/\(version:\).*/\1 $(DOCKER_TAG)/" -i $${CHART}/Chart.yaml; \
	done
	@if [ ! -z "$(COMMIT_$(COMMIT_TYPE))" -a "${COMMIT}" == "1" ]; then \
	    git commit -a -m 'New release $(CURRENT_VERSION)'; \
	    git format-patch -1 --stdout > $(RELEASE_PATCH_FILE); \
	    git tag -a $(CURRENT_VERSION) -m 'chore(release): release of $(CURRENT_VERSION)'; \
	fi
	@(\
	    echo "export CURRENT_VERSION=$(CURRENT_VERSION)"; \
	    echo "export PREV_VERSION=$(PREV_VERSION)"; \
	    echo "export DOCKER_REGISTRY=$(DOCKER_REGISTRY)"; \
	    echo "export RELEASE=$(RELEASE)"; \
	) > $@
	@echo "Release vars written in $@"

helm-package:
	@export HELM_HOME=/tmp; helm init --client-only; \
	for CHART in $(CHARTS_LIST); do \
	    helm package $${CHART}; \
	done

publish:
	if [ "$$(git rev-parse HEAD)" != "$$(git rev-parse @{u})" ]; then \
	    set -eu -o pipefail; \
	    git push origin $(CURRENT_VERSION); \
	    $(MAKE) docker-push; \
	    hub release create \
	    -a zenko-zookeeper-${DOCKER_TAG}.tgz \
	    -m '$(CURRENT_VERSION)' \
	    $(CURRENT_VERSION); \
	    git push origin master; \
	fi
endif

%.sh: %  # disable implicit rule for %.sh

# :vim set noexpandtab shiftwidth=8 softtabstop=0
