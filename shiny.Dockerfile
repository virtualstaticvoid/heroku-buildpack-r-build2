# syntax=docker/dockerfile:1.4

ARG BUILD_IMAGE
FROM $BUILD_IMAGE

ARG DEBIAN_FRONTEND=noninteractive

#
# NOTE:
#
#  httpuv package build yields lots of deprecation warnings
#  See https://github.com/rstudio/httpuv/issues/243 for more
#

RUN R --no-save --quiet -s -e "install.packages('shiny', clean=TRUE, quiet=TRUE)"
