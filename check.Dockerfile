# syntax=docker/dockerfile:1.4

ARG HEROKU_STACK
FROM heroku/heroku:$HEROKU_STACK-build

ARG CRAN_VERSION

# set default locale
ENV LANG=C.UTF-8

# set default timezone
ENV TZ=UTC

ARG DEBIAN_FRONTEND=noninteractive

# switch to root user, but no need to switch back as this image isn't run
USER root

# add R package apt sources
RUN ubuntu_codename=$(lsb_release -c | awk '{print $2}') \
 && keyid=E298A3A825C0D65DFD57CBB651716619E084DAB9 \
 && export GNUPGHOME="$(mktemp -d)" \
 && gpg --recv-keys --keyserver keyserver.ubuntu.com $keyid \
 && mkdir -p /etc/apt/keyrings \
 && gpg --export $keyid > /etc/apt/keyrings/cloud.r-project.org.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/cloud.r-project.org.gpg] https://cloud.r-project.org/bin/linux/ubuntu ${ubuntu_codename}-$CRAN_VERSION/" > /etc/apt/sources.list.d/r.list \
 && echo "deb-src [signed-by=/etc/apt/keyrings/cloud.r-project.org.gpg] https://cloud.r-project.org/bin/linux/ubuntu ${ubuntu_codename}-$CRAN_VERSION/" >> /etc/apt/sources.list.d/r.list

RUN apt-get update -q

CMD ["apt-cache", "policy", "r-base-dev"]
