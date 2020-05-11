# default target
all::

.PHONY: all
all:: build

R_VERSION?=3.6.3
BUILDPACK_NAME?=heroku-buildpack-r
BUILDPACK_VERSION?=latest

# NOTE: UBUNTU_IMAGE and HEROKU_STACK should line up
# e.g. heroku-18 == ubuntu:18.04
HEROKU_STACK?=18
UBUNTU_IMAGE?=ubuntu:$(HEROKU_STACK).04

BUILD_IMAGE:=$(BUILDPACK_NAME)-build-$(R_VERSION):$(HEROKU_STACK)
SHINY_IMAGE:=$(BUILDPACK_NAME)-shiny-$(R_VERSION):$(HEROKU_STACK)
PLUMBER_IMAGE:=$(BUILDPACK_NAME)-plumber-$(R_VERSION):$(HEROKU_STACK)

BUILD_ARCHIVE:=$(BUILDPACK_NAME)-$(HEROKU_STACK)-$(R_VERSION)-build.tar.gz
DEPLOY_ARCHIVE:=$(BUILDPACK_NAME)-$(HEROKU_STACK)-$(R_VERSION)-deploy.tar.gz
SHINY_ARCHIVE:=$(BUILDPACK_NAME)-$(HEROKU_STACK)-$(R_VERSION)-shiny.tar.gz
PLUM_ARCHIVE:=$(BUILDPACK_NAME)-$(HEROKU_STACK)-$(R_VERSION)-plumber.tar.gz

TCLTK_VERSION:=8.6.10
TCLTK_PATH:=8_6

R-$(R_VERSION).tar.gz:

	# download R sources
	curl -sLO https://cran.rstudio.com/src/base/R-3/R-$(R_VERSION).tar.gz

tcl$(TCLTK_VERSION)-src.tar.gz:

	# download tcl sources
	curl -sLO https://heroku-buildpack-r.s3.amazonaws.com/tcl$(TCLTK_VERSION)-src.tar.gz

tk$(TCLTK_VERSION)-src.tar.gz:

	# download tk sources
	curl -sLO https://heroku-buildpack-r.s3.amazonaws.com/tk$(TCLTK_VERSION)-src.tar.gz

.PHONY: .build_base
.build_base: R-$(R_VERSION).tar.gz tcl$(TCLTK_VERSION)-src.tar.gz tk$(TCLTK_VERSION)-src.tar.gz

	# build R binaries
	docker build --tag $(BUILD_IMAGE) \
							 --build-arg UBUNTU_IMAGE=$(UBUNTU_IMAGE) \
							 --build-arg R_VERSION=$(R_VERSION) \
							 --file Dockerfile.build .

	# this image is used during slug compilation
	docker run --rm --volume "$(PWD)/artifacts:/artifacts" $(BUILD_IMAGE) \
							 tar czf /artifacts/$(BUILD_ARCHIVE) --exclude-from=/artifacts/.tarignore  /

  # this archive is installed to /app/R side-by-side with project sources
  # "mounted" into chroot via /app
	docker run --rm --volume "$(PWD)/artifacts:/artifacts" $(BUILD_IMAGE) \
							 tar czf /artifacts/$(DEPLOY_ARCHIVE) R tcltk

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

.PHONY: .test_base
.test_base:

	# test build image
	docker run --tty --rm --volume "$(PWD)/test:/test" $(BUILD_IMAGE) \
							 /bin/bash -l /test/test.sh

.PHONY: .test_shiny
.test_shiny:

	# TODO: test for shiny image

.PHONY: .test_plumber
.test_plumber:

	# TODO: test for plumber image

.PHONY: build
build: .build_base .build_shiny .build_plumber

.PHONY: test
test: .test_base .test_shiny .test_plumber

.PHONY: publish
publish:

	# upload images to S3

	aws s3 cp artifacts/$(BUILD_ARCHIVE) \
			s3://$(BUILDPACK_NAME)/$(BUILDPACK_VERSION)/$(BUILD_ARCHIVE) \
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
