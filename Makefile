# default target
all::

.PHONY: all
all:: build

include Makefile.vars

APT_VERSION_IMAGE:=$(BUILDPACK_NAME)-apt-$(R_VERSION):$(HEROKU_STACK)
PRE_BUILD_IMAGE:=$(BUILDPACK_NAME)-prebuild-$(R_VERSION):$(HEROKU_STACK)
BUILD_IMAGE:=$(BUILDPACK_NAME)-build-$(R_VERSION):$(HEROKU_STACK)
CHROOT_IMAGE:=$(BUILDPACK_NAME)-chroot-$(R_VERSION):$(HEROKU_STACK)

SHINY_IMAGE:=$(BUILDPACK_NAME)-shiny-$(R_VERSION):$(HEROKU_STACK)
PLUMBER_IMAGE:=$(BUILDPACK_NAME)-plumber-$(R_VERSION):$(HEROKU_STACK)
TEST_IMAGE:=$(BUILDPACK_NAME)-test-$(R_VERSION):$(HEROKU_STACK)

CHROOT_ARCHIVE:=$(BUILDPACK_NAME)-$(HEROKU_STACK)-$(R_VERSION)-chroot.tar.gz
DEPLOY_ARCHIVE:=$(BUILDPACK_NAME)-$(HEROKU_STACK)-$(R_VERSION)-deploy.tar.gz
SHINY_ARCHIVE:=$(BUILDPACK_NAME)-$(HEROKU_STACK)-$(R_VERSION)-shiny.tar.gz
PLUM_ARCHIVE:=$(BUILDPACK_NAME)-$(HEROKU_STACK)-$(R_VERSION)-plumber.tar.gz

TCLTK_VERSION:=9.0.1
PANDOC_VERSION:=3.6.1

R_VERSION_MAJOR:=$(shell echo "$(R_VERSION)" | awk '{split($$0,a,"."); print a[1]}')

# fetch the cache key from the buildpack source
BUILDPACK_CACHE_KEY:=$(shell curl -sL https://raw.githubusercontent.com/$(BUILDPACK_REPO)/$(BUILDPACK_BRANCH)/bin/cache_key)

# enumerate test directories
TEST_DIRS:=$(shell cd test && find . -maxdepth 1 -type d | cut -c 3-)
TEST_TASKS:=$(addprefix .test_,$(TEST_DIRS))

ifeq ("$(BUILDPACK_TEST_DEBUG)","1")
TEST_INTERACTIVE:="--interactive"
endif

R-$(R_VERSION).tar.gz:

	# download R sources
	curl -fsSLO https://cran.rstudio.com/src/base/R-$(R_VERSION_MAJOR)/R-$(R_VERSION).tar.gz

tcl$(TCLTK_VERSION)-src.tar.gz:

	# download tcl sources
	curl -fsSLO https://heroku-buildpack-r.s3.amazonaws.com/tcl$(TCLTK_VERSION)-src.tar.gz

tk$(TCLTK_VERSION)-src.tar.gz:

	# download tk sources
	curl -fsSLO https://heroku-buildpack-r.s3.amazonaws.com/tk$(TCLTK_VERSION)-src.tar.gz

# -- BUILD

.PHONY: .pull
.pull:

	docker pull heroku/heroku:$(HEROKU_STACK)
	docker pull heroku/heroku:$(HEROKU_STACK)-build

.PHONY: .apt_check
.apt_check:

	docker build --progress=plain \
	             --tag $(APT_VERSION_IMAGE) \
							 --build-arg HEROKU_STACK=$(HEROKU_STACK) \
							 --build-arg CRAN_VERSION=$(CRAN_VERSION) \
							 --file check.Dockerfile .

	docker run --tty --rm $(APT_VERSION_IMAGE) > .apt_check.$(HEROKU_STACK)

.PHONY: .build_prebuild
.build_prebuild: R-$(R_VERSION).tar.gz tcl$(TCLTK_VERSION)-src.tar.gz tk$(TCLTK_VERSION)-src.tar.gz .pull

	# build R binaries
	docker build --progress=plain \
	             --tag $(PRE_BUILD_IMAGE) \
							 --build-arg HEROKU_STACK=$(HEROKU_STACK) \
							 --build-arg UBUNTU_IMAGE=$(UBUNTU_IMAGE) \
							 --build-arg R_VERSION=$(R_VERSION) \
							 --build-arg CRAN_VERSION=$(CRAN_VERSION) \
							 --build-arg TCLTK_VERSION=$(TCLTK_VERSION) \
							 --build-arg PANDOC_VERSION=$(PANDOC_VERSION) \
							 --file prebuild.Dockerfile .

.PHONY: .build_base
.build_base:

	docker build --progress=plain \
	             --tag $(BUILD_IMAGE) \
							 --build-arg PRE_BUILD_IMAGE=$(PRE_BUILD_IMAGE) \
							 --build-arg HEROKU_STACK=$(HEROKU_STACK) \
							 --build-arg R_VERSION=$(R_VERSION) \
							 --file build.Dockerfile .

.PHONY: .build_chroot
.build_chroot:

	docker build --progress=plain \
	             --tag $(CHROOT_IMAGE) \
							 --build-arg HEROKU_STACK=$(HEROKU_STACK) \
							 --build-arg R_VERSION=$(R_VERSION) \
							 --build-arg CRAN_VERSION=$(CRAN_VERSION) \
							 --file chroot.Dockerfile .

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
	docker build --progress=plain \
	             --tag $(SHINY_IMAGE) \
							 --build-arg BUILD_IMAGE=$(BUILD_IMAGE) \
							 --file shiny.Dockerfile .

	# this archive is installed to /app/R/site-library
	docker run --rm --volume "$(PWD)/artifacts:/artifacts" $(SHINY_IMAGE) \
						 tar czf /artifacts/$(SHINY_ARCHIVE) R/site-library

.PHONY: .build_plumber
.build_plumber:

	# build plumber binaries
	docker build --progress=plain \
	             --tag $(PLUMBER_IMAGE) \
							 --build-arg BUILD_IMAGE=$(BUILD_IMAGE) \
							 --file plumber.Dockerfile .

	# this archive is installed to /app/R/site-library
	docker run --rm --volume "$(PWD)/artifacts:/artifacts" $(PLUMBER_IMAGE) \
						 tar czf /artifacts/$(PLUM_ARCHIVE) R/site-library

.PHONY: .build_test
.build_test:

	docker build --progress=plain \
	             --tag $(TEST_IMAGE) \
							 --build-arg HEROKU_STACK=$(HEROKU_STACK) \
							 --file test/Dockerfile \
							 .

.PHONY: build
build: .build_prebuild .build_base .build_chroot .build_archives .build_shiny .build_plumber .build_test

# -- TEST

.PHONY: $(TEST_TASKS)
$(TEST_TASKS):

	@echo "Executing $(subst .test_,,$@) test..."

	# generate name for volume
	$(eval volname=buildpack_$(HEROKU_STACK)_$(BUILDPACK_VERSION)_$(subst .,,$@))

	# create volume to store test app
	@docker volume rm $(volname) || /bin/true
	@docker volume create --name $(volname)

	# copy test app into volume
	@docker run --tty --rm \
						 --volume "$(volname):/heroku" \
						 --volume "$(PWD)/$(subst .test_,test/,$@):/test" \
						 $(UBUNTU_IMAGE) \
						 /bin/bash -c 'mkdir -p /heroku/{buildpack,build,cache,env} && cd /test && cp -fR . /heroku/build'

	# "compile" app
	docker run --tty --rm $(TEST_INTERACTIVE) \
						 --env R_VERSION=$(R_VERSION) \
						 --env BUILDPACK_CLONE_URL=$(BUILDPACK_CLONE_URL) \
						 --env BUILDPACK_BRANCH=$(BUILDPACK_BRANCH) \
						 --env BUILDPACK_VERSION=$(BUILDPACK_VERSION) \
						 --env BUILDPACK_CACHE_KEY=$(BUILDPACK_CACHE_KEY) \
						 --env BUILDPACK_DEBUG=$(BUILDPACK_DEBUG) \
						 --env BUILDPACK_TEST_DEBUG=$(BUILDPACK_TEST_DEBUG) \
						 --env PACKAGE_INSTALL_VERBOSE=$(PACKAGE_INSTALL_VERBOSE) \
						 --volume "$(volname):/heroku" \
						 --volume "$(PWD)/artifacts/$(CHROOT_ARCHIVE):/heroku/cache/$(BUILDPACK_VERSION)-$(HEROKU_STACK)-$(BUILDPACK_CACHE_KEY)-build.tar.gz:ro" \
						 --volume "$(PWD)/artifacts/$(DEPLOY_ARCHIVE):/heroku/cache/$(BUILDPACK_VERSION)-$(HEROKU_STACK)-$(BUILDPACK_CACHE_KEY)-deploy.tar.gz:ro" \
						 --volume "$(PWD)/artifacts/$(SHINY_ARCHIVE):/heroku/cache/$(BUILDPACK_VERSION)-$(HEROKU_STACK)-$(BUILDPACK_CACHE_KEY)-shiny.tar.gz:ro" \
						 --volume "$(PWD)/artifacts/$(PLUM_ARCHIVE):/heroku/cache/$(BUILDPACK_VERSION)-$(HEROKU_STACK)-$(BUILDPACK_CACHE_KEY)-plumber.tar.gz:ro" \
						 $(TEST_IMAGE)

.PHONY: test
test: $(TEST_TASKS)

# -- PUBLISH

.PHONY: upload_artifacts
upload_artifacts:

	# upload images to S3

	aws s3 cp artifacts/$(CHROOT_ARCHIVE) \
			s3://$(BUILDPACK_NAME)/$(BUILDPACK_VERSION)/$(CHROOT_ARCHIVE) \
			--acl=public-read \
			--no-progress

	aws s3 cp artifacts/$(DEPLOY_ARCHIVE) \
			s3://$(BUILDPACK_NAME)/$(BUILDPACK_VERSION)/$(DEPLOY_ARCHIVE) \
			--acl=public-read \
			--no-progress

	aws s3 cp artifacts/$(SHINY_ARCHIVE) \
			s3://$(BUILDPACK_NAME)/$(BUILDPACK_VERSION)/$(SHINY_ARCHIVE) \
			--acl=public-read \
			--no-progress

	aws s3 cp artifacts/$(PLUM_ARCHIVE) \
			s3://$(BUILDPACK_NAME)/$(BUILDPACK_VERSION)/$(PLUM_ARCHIVE) \
			--acl=public-read \
			--no-progress

.PHONY: publish
publish:

	# publish to default location

	aws s3 cp s3://$(BUILDPACK_NAME)/$(BUILDPACK_VERSION)/$(CHROOT_ARCHIVE) \
			s3://$(BUILDPACK_NAME)/latest/$(CHROOT_ARCHIVE) \
			--acl=public-read \
			--no-progress

	aws s3 cp s3://$(BUILDPACK_NAME)/$(BUILDPACK_VERSION)/$(DEPLOY_ARCHIVE) \
			s3://$(BUILDPACK_NAME)/latest/$(DEPLOY_ARCHIVE) \
			--acl=public-read \
			--no-progress

	aws s3 cp s3://$(BUILDPACK_NAME)/$(BUILDPACK_VERSION)/$(SHINY_ARCHIVE) \
			s3://$(BUILDPACK_NAME)/latest/$(SHINY_ARCHIVE) \
			--acl=public-read \
			--no-progress

	aws s3 cp s3://$(BUILDPACK_NAME)/$(BUILDPACK_VERSION)/$(PLUM_ARCHIVE) \
			s3://$(BUILDPACK_NAME)/latest/$(PLUM_ARCHIVE) \
			--acl=public-read \
			--no-progress
