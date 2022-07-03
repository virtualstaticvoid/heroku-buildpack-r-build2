# default target
all::

.PHONY: all
all:: build

include ../../Makefile.vars

UID:=$(shell id -u)
GID:=$(shell id -g)

.PHONY: build
build:
	docker run -it --rm --user "$(UID):$(GID)" -v "$(PWD):/app" --workdir=/app r-base:$(R_VERSION) \
		/usr/bin/R --no-save --quiet -s --file=/app/setup.R
