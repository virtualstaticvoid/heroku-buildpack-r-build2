# syntax=docker/dockerfile:1.4

#
# prepares the image for creating the archive
# e.g. removes unneeded files
#

ARG PRE_BUILD_IMAGE
FROM $PRE_BUILD_IMAGE

ARG HEROKU_STACK
ARG R_VERSION

ARG DEBIAN_FRONTEND=noninteractive

# working directory is /app

# build fakechroot
#ARG FAKECHROOT_VER=2.20.1
ARG FAKECHROOT_VER=ldd2

RUN git clone -b "$FAKECHROOT_VER" --single-branch --depth 1 https://github.com/virtualstaticvoid/fakechroot.git fakechroot-src \
 && cd fakechroot-src \
 && ./autogen.sh \
 && ./configure --prefix=/app/fakechroot \
 && make > /dev/null \
 && make install \
 && cd .. \
 && rm -rf fakechroot-src

# copy helpers and profile
COPY scripts/helpers.R /app/R/etc/helpers.R
COPY scripts/Rprofile.site /app/R/lib/R/etc/Rprofile.site

# clean up
RUN rm -rf R-$R_VERSION \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
 && touch /app/R/site-library/.keep

# --- for running this image

# set path for testing within docker container
ENV PATH="/app/bin:/app/R/bin:/app/R/lib/R/bin:/app/tcltk/bin:/app/pandoc/bin:$PATH"

# set user site library
ENV R_LIBS_USER="/app/R/site-library"

# so that R can find pandoc
ENV RSTUDIO_PANDOC="/app/pandoc/bin"

# run R without session saving
CMD ["R", "--no-save"]
