# default target
all::

.PHONY: all
all:: build

R_VERSION?=4.0.0
CRAN_VERSION?=cran40

BUILDPACK_NAME?=heroku-buildpack-r
BUILDPACK_VERSION?=latest
BUILDPACK_REPO?=virtualstaticvoid/$(BUILDPACK_NAME)
BUILDPACK_CLONE_URL:=https://github.com/$(BUILDPACK_REPO).git
BUILDPACK_BRANCH?=master
BUILDPACK_DEBUG?=

# NOTE: UBUNTU_IMAGE and HEROKU_STACK should line up
# e.g. heroku-18 == ubuntu:18.04
HEROKU_STACK?=18
UBUNTU_IMAGE?=ubuntu:$(HEROKU_STACK).04

PRE_BUILD_IMAGE:=$(BUILDPACK_NAME)-prebuild-$(R_VERSION):$(HEROKU_STACK)
BUILD_IMAGE:=$(BUILDPACK_NAME)-build-$(R_VERSION):$(HEROKU_STACK)
CHROOT_IMAGE:=$(BUILDPACK_NAME)-chroot-$(R_VERSION):$(HEROKU_STACK)

SHINY_IMAGE:=$(BUILDPACK_NAME)-shiny-$(R_VERSION):$(HEROKU_STACK)
PLUMBER_IMAGE:=$(BUILDPACK_NAME)-plumber-$(R_VERSION):$(HEROKU_STACK)
TEST_IMAGE:=$(BUILDPACK_NAME)-e2e-$(R_VERSION):$(HEROKU_STACK)

CHROOT_ARCHIVE:=$(BUILDPACK_NAME)-$(HEROKU_STACK)-$(R_VERSION)-chroot.tar.gz
DEPLOY_ARCHIVE:=$(BUILDPACK_NAME)-$(HEROKU_STACK)-$(R_VERSION)-deploy.tar.gz
SHINY_ARCHIVE:=$(BUILDPACK_NAME)-$(HEROKU_STACK)-$(R_VERSION)-shiny.tar.gz
PLUM_ARCHIVE:=$(BUILDPACK_NAME)-$(HEROKU_STACK)-$(R_VERSION)-plumber.tar.gz

TCLTK_VERSION:=8.6.10

R_VERSION_MAJOR:=$(shell echo "$(R_VERSION)" | awk '{split($$0,a,"."); print a[1]}')

# fetch the cache key from the buildpack source
BUILDPACK_CACHE_KEY:=$(shell curl -sL https://raw.githubusercontent.com/$(BUILDPACK_REPO)/$(BUILDPACK_BRANCH)/bin/cache_key)

# enumerate test directories
TEST_DIRS:=$(shell cd test && find . -maxdepth 1 -type d | cut -c 3-)
TEST_TASKS:=$(addprefix .test_,$(TEST_DIRS))

R-$(R_VERSION).tar.gz:

	# download R sources
	curl -sLO https://cran.rstudio.com/src/base/R-$(R_VERSION_MAJOR)/R-$(R_VERSION).tar.gz

tcl$(TCLTK_VERSION)-src.tar.gz:

	# download tcl sources
	curl -sLO https://heroku-buildpack-r.s3.amazonaws.com/tcl$(TCLTK_VERSION)-src.tar.gz

tk$(TCLTK_VERSION)-src.tar.gz:

	# download tk sources
	curl -sLO https://heroku-buildpack-r.s3.amazonaws.com/tk$(TCLTK_VERSION)-src.tar.gz

# -- BUILD

.PHONY: .build_prebuild
.build_prebuild: R-$(R_VERSION).tar.gz tcl$(TCLTK_VERSION)-src.tar.gz tk$(TCLTK_VERSION)-src.tar.gz

	# build R binaries
	docker build --tag $(PRE_BUILD_IMAGE) \
							 --build-arg HEROKU_STACK=$(HEROKU_STACK) \
							 --build-arg UBUNTU_IMAGE=$(UBUNTU_IMAGE) \
							 --build-arg R_VERSION=$(R_VERSION) \
							 --build-arg CRAN_VERSION=$(CRAN_VERSION) \
							 --file Dockerfile.prebuild .

.PHONY: .build_base
.build_base:

	docker build --tag $(BUILD_IMAGE) \
							 --build-arg PRE_BUILD_IMAGE=$(PRE_BUILD_IMAGE) \
							 --build-arg HEROKU_STACK=$(HEROKU_STACK) \
							 --build-arg R_VERSION=$(R_VERSION) \
							 --file Dockerfile.build .

.PHONY: .build_chroot
.build_chroot:

	docker build --tag $(CHROOT_IMAGE) \
							 --build-arg HEROKU_STACK=$(HEROKU_STACK) \
							 --build-arg R_VERSION=$(R_VERSION) \
							 --build-arg CRAN_VERSION=$(CRAN_VERSION) \
							 --file Dockerfile.chroot .

.PHONY: .build_archives
.build_archives:

	# this image is used during slug compilation
	docker run --rm --volume "$(PWD)/artifacts:/artifacts" $(CHROOT_IMAGE) \
							 tar czf /artifacts/$(CHROOT_ARCHIVE) --exclude-from=/artifacts/.tarignore  /

	# this archive is installed to /app/R side-by-side with project sources
	# "mounted" into chroot via /app
	docker run --rm --volume "$(PWD)/artifacts:/artifacts" $(BUILD_IMAGE) \
							 tar czf /artifacts/$(DEPLOY_ARCHIVE) R tcltk pandoc fakechroot

.PHONY: .build_shiny
.build_shiny:

	# build shiny binaries
	docker build --tag $(SHINY_IMAGE) \
							 --build-arg BUILD_IMAGE=$(BUILD_IMAGE) \
							 --file Dockerfile.shiny .

	# this archive is installed to /app/R/site-library
	docker run --rm --volume "$(PWD)/artifacts:/artifacts" $(SHINY_IMAGE) \
						 tar czf /artifacts/$(SHINY_ARCHIVE) R/site-library

.PHONY: .build_plumber
.build_plumber:

	# build plumber binaries
	docker build --tag $(PLUMBER_IMAGE) \
							 --build-arg BUILD_IMAGE=$(BUILD_IMAGE) \
							 --file Dockerfile.plumber .

	# this archive is installed to /app/R/site-library
	docker run --rm --volume "$(PWD)/artifacts:/artifacts" $(PLUMBER_IMAGE) \
						 tar czf /artifacts/$(PLUM_ARCHIVE) R/site-library

.PHONY: .build_test
.build_test:

	docker build --tag $(TEST_IMAGE) \
							 --build-arg HEROKU_STACK=$(HEROKU_STACK) \
							 --file test/Dockerfile \
							 .

.PHONY: build
build: .build_prebuild .build_base .build_chroot .build_archives .build_shiny .build_plumber .build_test

# -- TEST

.PHONY: .test_build
.test_build:

	# test build image
	docker run --tty --rm --volume "$(PWD)/test:/test" $(BUILD_IMAGE) \
							 /bin/bash -l /test/test.sh

.PHONY: $(E2E_TEST_TASKS)
$(E2E_TEST_TASKS):

	# create volume to store test app
	docker volume rm buildpack_$(subst .,,$@) || /bin/true
	docker volume create --name buildpack_$(subst .,,$@)

	# copy test app into volume
	docker run --rm \
						 --volume "buildpack_$(subst .,,$@):/heroku" \
						 --volume "$(PWD)/$(subst .test_e2e_,e2e/,$@):/test" \
						 $(UBUNTU_IMAGE) \
						 /bin/bash -c 'mkdir -p /heroku/{buildpack,build,cache,env} && cd /test && cp -fR . /heroku/build'

	# "compile" app
	docker run --interactive --tty --rm \
						 --env BUILDPACK_CLONE_URL=$(BUILDPACK_CLONE_URL) \
						 --env BUILDPACK_BRANCH=$(BUILDPACK_BRANCH) \
						 --env BUILDPACK_VERSION=$(BUILDPACK_VERSION) \
						 --env BUILDPACK_CACHE_KEY=$(BUILDPACK_CACHE_KEY) \
						 --env BUILDPACK_DEBUG=$(BUILDPACK_DEBUG) \
						 --volume "buildpack_$(subst .,,$@):/heroku" \
						 --volume "$(PWD)/artifacts/$(CHROOT_ARCHIVE):/heroku/cache/$(BUILDPACK_VERSION)-$(HEROKU_STACK)-$(BUILDPACK_CACHE_KEY)-build.tar.gz:ro" \
						 --volume "$(PWD)/artifacts/$(DEPLOY_ARCHIVE):/heroku/cache/$(BUILDPACK_VERSION)-$(HEROKU_STACK)-$(BUILDPACK_CACHE_KEY)-deploy.tar.gz:ro" \
						 --volume "$(PWD)/artifacts/$(SHINY_ARCHIVE):/heroku/cache/$(BUILDPACK_VERSION)-$(HEROKU_STACK)-$(BUILDPACK_CACHE_KEY)-shiny.tar.gz:ro" \
						 --volume "$(PWD)/artifacts/$(PLUM_ARCHIVE):/heroku/cache/$(BUILDPACK_VERSION)-$(HEROKU_STACK)-$(BUILDPACK_CACHE_KEY)-plumber.tar.gz:ro" \
						 $(E2E_IMAGE)

.PHONY: test
test: .test_build $(TEST_TASKS)

# -- PUBLISH

.PHONY: publish
publish:

	# upload images to S3

	aws s3 cp artifacts/$(CHROOT_ARCHIVE) \
			s3://$(BUILDPACK_NAME)/$(BUILDPACK_VERSION)/$(CHROOT_ARCHIVE) \
			--acl=public-read

	aws s3 cp artifacts/$(DEPLOY_ARCHIVE) \
			s3://$(BUILDPACK_NAME)/$(BUILDPACK_VERSION)/$(DEPLOY_ARCHIVE) \
			--acl=public-read

	aws s3 cp artifacts/$(SHINY_ARCHIVE) \
			s3://$(BUILDPACK_NAME)/$(BUILDPACK_VERSION)/$(SHINY_ARCHIVE) \
			--acl=public-read

	aws s3 cp artifacts/$(PLUM_ARCHIVE) \
			s3://$(BUILDPACK_NAME)/$(BUILDPACK_VERSION)/$(PLUM_ARCHIVE) \
			--acl=public-read
