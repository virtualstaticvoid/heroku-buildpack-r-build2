# syntax=docker/dockerfile:1.4

ARG BUILD_IMAGE
FROM $BUILD_IMAGE

ARG DEBIAN_FRONTEND=noninteractive

# plumber dependencies
RUN apt-get update -q \
 && apt-get install -qy --no-install-recommends \
      libsodium-dev \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

#
# NOTE:
#
#  httpuv package build yields lots of deprecation warnings
#  See https://github.com/rstudio/httpuv/issues/243 for more
#

RUN R --no-save --quiet -s -e "install.packages('plumber', clean=TRUE, quiet=TRUE)"
