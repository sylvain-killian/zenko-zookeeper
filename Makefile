
DOCKERFILES_DIR = images
DOCKER_REGISTRY ?=
ifneq ($(DOCKER_REGISTRY),)
# Ensure there is '/' at the end of Docker regsitry
DOCKER_REGISTRY := $(DOCKER_REGISTRY:/=)/
endif

BUILD_DIR = build
BUILD_ENV_FILE = $(BUILD_DIR)/env.sh
RELEASE_PATCH_FILE = $(BUILD_DIR)/release.patch

VALUES_YAML ?= charts/zenko-zookeeper/values.yaml

COMMIT_fix := patch
COMMIT_feat := minor


DOCKERFILES = $(wildcard $(DOCKERFILES_DIR)/*)
DOCKER_IMAGES = $(foreach docker,$(DOCKERFILES),$(notdir $(docker)))

DOCKER_CHECK_BUILD_TARGETS := $(foreach image,${DOCKER_IMAGES},docker-check-build/$(image))
DOCKER_OLD_TAG_TARGETS := $(foreach image,${DOCKER_IMAGES},docker-old-tag/$(image))
DOCKER_CHECK_TARGETS := $(foreach image,${DOCKER_IMAGES},docker-check/$(image))
DOCKER_BUILD_TARGETS := $(foreach image,${DOCKER_IMAGES},docker-build/$(image))
DOCKER_PUSH_TARGETS := $(foreach image,${DOCKER_IMAGES},docker-push/$(image))

define release-vars
  PREV_VERSION ?= $$(shell git describe --tags --abbrev=0)
  PREV_VERSION := $$(PREV_VERSION)
  COMMIT_PARSED := $$(shell git log -1 --pretty=%B|conventional-commits-parser)
  COMMIT_TYPE ?= $$(shell echo '$$(COMMIT_PARSED)'| jq '.[0].type')
  COMMIT_TYPE := $$(COMMIT_TYPE)
  GIT_DIRTY ?= $$(shell git diff --quiet HEAD && echo 0)
  GIT_DIRTY := $$(GIT_DIRTY)
  ifeq ($$(RELEASE),1)
    ifeq ($$(GIT_DIRTY),0)
      # /!\ semver strip the 'v': `semver v0.0.3 -i patch` == 0.0.4
      NEXT_VERSION ?= v$$(shell semver $$(PREV_VERSION) -i $$(COMMIT_$$(COMMIT_TYPE)))
    else
      $$(error Cannot release with an unclean history (or git not installed))
    endif
  endif
  NEXT_VERSION := $$(NEXT_VERSION)
  # Remove the 'v' of git tag (v0.0.2 -> 0.0.2)
  NEXT_DOCKER_TAG := $$(or $$(NEXT_VERSION:v%=%),latest)
endef

define target_to_image
  IMAGE := $$(lastword $$(subst /, ,$(1)))
  DOCKER_DIR := $(DOCKERFILES_DIR)/$$(IMAGE)
endef

define image_to_tag
  IMAGE_TAG := $(1):$(NEXT_DOCKER_TAG)
  ifneq ($(DOCKER_REGISTRY),)
    IMAGE_TAG := $(DOCKER_REGISTRY)$$(IMAGE_TAG)
  endif
endef

define sed_helm_image
  ifeq ($$($(1)_ALREADY_BUILT),0)
    $$(shell sed -e "s/\(ImageTag:\).*/\1 $(NEXT_DOCKER_TAG)/" -i $(VALUES_YAML))
  endif
endef

RUN_DOCKER ?= 1
DOCKER_RELENG ?= zenko/zenko-releng:0.0.3
CONTAINERIZED_TARGETS := release \
			 $(DOCKER_CHECK_BUILD_TARGETS) \
			 $(DOCKER_BUILD_TARGETS) \
			 $(DOCKER_PUSH_TARGETS)


.PHONY: write-env release-vars $(BUILD_ENV_FILE) docker-build docker-push clean

clean:
	rm -rf $(BUILD_ENV_FILE)

$(BUILD_DIR):
	mkdir $@

docker-check-build: $(DOCKER_CHECK_BUILD_TARGETS)
docker-build: $(DOCKER_BUILD_TARGETS)
docker-push: $(DOCKER_PUSH_TARGETS)

ifeq ($(RUN_DOCKER),1)

$(CONTAINERIZED_TARGETS):
	docker run --rm \
	-v $$(pwd):/workdir \
	-v /var/run/docker.sock:/var/run/docker.sock \
	$(DOCKER_RELENG) \
	sh -c '[ -f $(BUILD_ENV_FILE) ] && . ./$(BUILD_ENV_FILE); make $@ $(MAKEFLAGS)'

else

$(DOCKER_CHECK_TARGETS): release-vars
	$(eval $(call target_to_image,$@))
	$(eval $(call image_to_tag,$(IMAGE)))
	$(eval $(IMAGE)_GIT_REV=$(shell git log -n 1 --pretty=format:%H -- $(DOCKERFILES_DIR)))
	$(eval $(IMAGE)_ALREADY_BUILT=$(shell git tag $(PREV_VERSION) -l --contains $($(IMAGE)_GIT_REV)|wc -l))

$(DOCKER_CHECK_BUILD_TARGETS): ${DOCKER_CHECK_TARGETS}
	$(eval $(call target_to_image,$@))
	$(eval $(call image_to_tag,$(IMAGE)))
	@export IMAGE_BUILT=$($(IMAGE)_ALREADY_BUILT); \
	if [ 0 -eq "$${IMAGE_BUILT}" ]; then \
	    echo "Image '$(IMAGE)' must be built"; \
	    $(MAKE) docker-build/$(IMAGE); \
	else \
	    echo "Image '$(IMAGE)' already built"; \
	fi

$(DOCKER_OLD_TAG_TARGETS): release-vars
	$(eval $(call target_to_image,$@))
	$(eval $(call image_to_tag,$(IMAGE)))
	VALUES_CONTENT=$(shell git show $(CUR_VERSION):$(VALUES_YAML))
	$(eval $(IMAGE)_PREV=$(shell grep $(VALUES_CONTENT) 'Image'))
	@echo ${$(IMAGE)_PREV}

${DOCKER_BUILD_TARGETS}: release-vars
	$(eval $(call target_to_image,$@))
	$(eval $(call image_to_tag,$(IMAGE)))
	@echo "=================================================="
	@echo "Building ${IMAGE} (Tagged: ${IMAGE_TAG})"
	@echo "=================================================="
	cd ${DOCKER_DIR}; \
	DOCKER_REGISTRY=$(DOCKER_REGISTRY) \
	DOCKER_TAG=$(NEXT_DOCKER_TAG) \
	./build.sh

${DOCKER_PUSH_TARGETS}: release-vars
	$(eval $(call target_to_image,$@))
	$(eval $(call image_to_tag,$(IMAGE)))
	docker push ${IMAGE_TAG}

release: RELEASE=1
release: $(DOCKER_CHECK_TARGETS) $(BUILD_ENV_FILE)
	$(foreach image,$(DOCKER_IMAGES),$(eval $(call sed_helm_image,$(image))))
	@echo "Release vars written in $(BUILD_ENV_FILE)"
	@git config --global user.email "ci-zenko@scality.com"
	@git commit -a -m 'New release $(NEXT_VERSION)'
	@git tag -a $(NEXT_VERSION) -m 'Release of $(NEXT_VERSION)'
	@git format-patch -1 --stdout > $(RELEASE_PATCH_FILE)

$(BUILD_ENV_FILE): release-vars |$(BUILD_DIR)
	@(\
		echo "export NEXT_VERSION=$(NEXT_VERSION)"; \
		echo "export PREV_VERSION=$(PREV_VERSION)"; \
		echo "export DOCKER_REGISTRY=$(DOCKER_REGISTRY)"; \
		echo "export RELEASE=$(RELEASE)"; \
	) > $@

release-vars:
	$(eval $(call release-vars))

endif

%.sh: %  # disable implicit rule for %.sh

# :vim set noexpandtab shiftwidth=8 softtabstop=0
