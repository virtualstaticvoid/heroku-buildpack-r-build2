# syntax=docker/dockerfile:1.4

ARG HEROKU_STACK
FROM heroku/heroku:$HEROKU_STACK-build

ARG HEROKU_STACK
ARG R_VERSION
ARG CRAN_VERSION

# set default locale
ENV LANG=C.UTF-8

# set default timezone
ENV TZ=UTC

ARG DEBIAN_FRONTEND=noninteractive

# switch to root user, but no need to switch back as this image isn't run
USER root

# install base utilities
RUN apt-get update -q \
 && apt-get install -qy --no-install-recommends \
      apt-transport-https \
      autoconf \
      automake \
      build-essential \
      curl \
      fakeroot \
      gawk \
      git \
      gnupg2 \
      libcurl4-openssl-dev \
      libicu-dev \
      libopenblas-dev \
      libpcre2-dev \
      libpq-dev \
      libssl-dev \
      libtool \
      lsb-release \
      m4 \
      ruby \
      tcl-dev \
      tk-dev \
      unzip \
      wget \
      xz-utils \
      zip \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# add R package apt sources
RUN ubuntu_codename=$(lsb_release -c | awk '{print $2}') \
 && keyid=E298A3A825C0D65DFD57CBB651716619E084DAB9 \
 && export GNUPGHOME="$(mktemp -d)" \
 && gpg --recv-keys --keyserver keyserver.ubuntu.com $keyid \
 && mkdir -p /etc/apt/keyrings \
 && gpg --export $keyid > /etc/apt/keyrings/cloud.r-project.org.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/cloud.r-project.org.gpg] https://cloud.r-project.org/bin/linux/ubuntu ${ubuntu_codename}-$CRAN_VERSION/" > /etc/apt/sources.list.d/r.list \
 && echo "deb-src [signed-by=/etc/apt/keyrings/cloud.r-project.org.gpg] https://cloud.r-project.org/bin/linux/ubuntu ${ubuntu_codename}-$CRAN_VERSION/" >> /etc/apt/sources.list.d/r.list

# figure out dependent packages of r-base-core and r-base-dev
RUN --mount=type=bind,source=scripts/pkg_depends.rb,target=pkg_depends.rb \
    apt-get update -q \
 && PACKAGES=$(ruby pkg_depends.rb $R_VERSION) \
 && apt-get install -qy $PACKAGES \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# add R and tcltk libraries to ldd search paths
COPY scripts/ldd.conf /etc/ld.so.conf.d/app-R-tcltk.conf

#
# clear out dpkg overrides, to avoid the following error
#
#  dpkg: unrecoverable fatal error, aborting:
#   unknown system group '....' in statoverride file; the system group got removed
#  before the override, which is most probably a packaging bug, to recover you
#  can remove the override manually with dpkg-statoverride
#
RUN rm -f /var/lib/dpkg/statoverride \
 && touch /var/lib/dpkg/statoverride
