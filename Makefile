
DOCKERFILES_DIR = dockerfiles
DOCKER_REPOSITORY ?=

ifeq ($(RELEASE),1)
  GIT_DIRTY := $(shell git diff --quiet HEAD; echo $$?)
  ifeq ($(GIT_DIRTY),0)
  VERSION ?= $(shell git describe)
  else
    $(error trying to release, but git is not installed or indicates changes)
  endif
endif

VERSION := $(or $(VERSION),latest)

DOCKERFILES = $(wildcard $(DOCKERFILES_DIR)/*)
DOCKER_IMAGES = $(foreach docker,$(DOCKERFILES),$(notdir $(docker)))

DOCKER_BUILD_TARGETS := $(foreach image,${DOCKER_IMAGES},docker-build/$(image))
DOCKER_PUSH_TARGETS := $(foreach image,${DOCKER_IMAGES},docker-push/$(image))

define target_to_image
  IMAGE := $$(lastword $$(subst /, ,$(1)))
  DOCKER_DIR := $(DOCKERFILES_DIR)/$$(IMAGE)
endef

define image_to_tag
  IMAGE_TAG := $(1):$(VERSION)
  ifneq ($(DOCKER_REPOSITORY),)
    IMAGE_TAG := $(DOCKER_REPOSITORY)/$$(IMAGE_TAG)
  endif
endef

${DOCKER_BUILD_TARGETS}:
	$(eval $(call target_to_image,$@))
	$(eval $(call image_to_tag,$(IMAGE)))
	@echo "=================================================="
	@echo "Building ${IMAGE} (Tagged: ${IMAGE_TAG})"
	@echo "=================================================="
	@docker build ${DOCKER_DIR} -t ${IMAGE_TAG}

docker-build: ${DOCKER_BUILD_TARGETS}

${DOCKER_PUSH_TARGETS}:
	$(eval $(call target_to_image,$@))
	$(eval $(call image_to_tag,$(IMAGE)))
	docker push ${IMAGE_TAG}

docker-push: ${DOCKER_PUSH_TARGETS}

# :vim set noexpandtab shiftwidth=8 softtabstop=0
