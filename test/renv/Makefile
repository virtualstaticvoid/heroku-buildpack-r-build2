# default target
all::

.PHONY: all
all:: build

include ../../Makefile.vars

build:
	docker run -it --rm -v "$(PWD):/app" --workdir=/app r-base:$(R_VERSION) \
		/usr/bin/R --no-save --quiet -s --file=/app/setup.R
