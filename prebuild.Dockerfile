# syntax=docker/dockerfile:1.4

#
# installs pre-requisites, build environment and compiles R
#

ARG UBUNTU_IMAGE
FROM $UBUNTU_IMAGE

ARG HEROKU_STACK
ARG R_VERSION
ARG CRAN_VERSION

# set default locale
ENV LANG=C.UTF-8

# set default timezone
ENV TZ=UTC

# heroku uses /app
RUN mkdir -p /app /app/bin /app/R/site-library
WORKDIR /app

ARG DEBIAN_FRONTEND=noninteractive

# enable package sources
RUN sed -i "s|# deb-src|deb-src|g" /etc/apt/sources.list

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

# Tcl / Tk
ARG TCLTK_VERSION

RUN --mount=type=bind,source=tcl${TCLTK_VERSION}-src.tar.gz,target=tcl-src.tar.gz \
    tar xf tcl-src.tar.gz \
 && cd tcl${TCLTK_VERSION}/unix \
 && ./configure --prefix=/app/tcltk \
 && make > /dev/null \
 && make install \
 && cd /app \
 && rm -rf tcl${TCLTK_VERSION}

RUN --mount=type=bind,source=tk${TCLTK_VERSION}-src.tar.gz,target=tk-src.tar.gz \
    tar xf tk-src.tar.gz \
 && cd tk${TCLTK_VERSION}/unix \
 && export CPATH=/app/tcltk/include \
 && ./configure --prefix=/app/tcltk \
                --with-tcl=/app/tcltk/lib \
 && make > /dev/null \
 && make install \
 && cd /app \
 && rm -rf tk${TCLTK_VERSION}

# pandoc
ARG PANDOC_VERSION
RUN curl -sL https://github.com/jgm/pandoc/releases/download/${PANDOC_VERSION}/pandoc-${PANDOC_VERSION}-linux-amd64.tar.gz -o pandoc.tar.gz \
 && tar xf pandoc.tar.gz \
 && mv pandoc-${PANDOC_VERSION} pandoc \
 && rm pandoc.tar.gz

# add R package apt sources
RUN ubuntu_codename=$(lsb_release -c | awk '{print $2}') \
 && keyid=E298A3A825C0D65DFD57CBB651716619E084DAB9 \
 && export GNUPGHOME="$(mktemp -d)" \
 && gpg --recv-keys --keyserver keyserver.ubuntu.com $keyid \
 && mkdir -p /etc/apt/keyrings \
 && gpg --export $keyid > /etc/apt/keyrings/cloud.r-project.org.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/cloud.r-project.org.gpg] https://cloud.r-project.org/bin/linux/ubuntu ${ubuntu_codename}-$CRAN_VERSION/" > /etc/apt/sources.list.d/r.list \
 && echo "deb-src [signed-by=/etc/apt/keyrings/cloud.r-project.org.gpg] https://cloud.r-project.org/bin/linux/ubuntu ${ubuntu_codename}-$CRAN_VERSION/" >> /etc/apt/sources.list.d/r.list

# -> specifying the R version doesn't work with build-dep (potential version mismatch issue?)
# RUN apt-get update -q && apt-get build-dep -qqy --no-install-recommends r-base=${R_VERSION}*
RUN apt-get update -q \
 && apt-get build-dep -qy --no-install-recommends r-base \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

RUN --mount=type=bind,source=R-$R_VERSION.tar.gz,target=R-$R_VERSION.tar.gz \
    tar xzf R-$R_VERSION.tar.gz

# https://cran.r-project.org/doc/manuals/R-admin.html#Installing-R-under-Unix_002dalikes

RUN cd R-$R_VERSION \
 && export DEBIAN_FRONTEND=noninteractive \
 && export AWK=/usr/bin/awk \
 && export LIBnn=lib \
 && export PERL=/usr/bin/perl \
 && export R_BROWSER=/bin/false \
 && export R_LIBS_USER=/app/R/site-library \
 && export R_PAPERSIZE=letter \
 && export R_PDFVIEWER=/bin/false \
 && export R_PRINTCMD=/usr/bin/lpr \
 && export R_UNZIPCMD=/usr/bin/unzip \
 && export R_ZIPCMD=/usr/bin/zip \
 && ./configure --prefix=/app/R \
                --with-blas \
                --with-lapack \
                --with-tcltk \
                --with-tcl-config=/app/tcltk/lib/tclConfig.sh \
                --with-tk-config=/app/tcltk/lib/tkConfig.sh \
                --with-x \
                --enable-R-shlib \
                --enable-memory-profiling

RUN cd R-$R_VERSION \
 && make > /dev/null

# this fails...
# RUN cd R-$R_VERSION \
#  && make check

RUN cd R-$R_VERSION \
 && make install

RUN echo "\nPKG_LIBS += $(pkg-config --libs openblas)" >> /app/R/lib/R/share/make/vars.mk
