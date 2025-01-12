ARG HEROKU_STACK
FROM heroku/heroku:$HEROKU_STACK-build

ARG HEROKU_STACK

# set Heroku environment variables
ENV STACK=heroku-$HEROKU_STACK
ENV APP_DIR=/app
ENV HEROKU_DIR=/heroku
ENV BUILDPACK_DIR=$HEROKU_DIR/buildpack
ENV BUILD_DIR=$HEROKU_DIR/build
ENV CACHE_DIR=$HEROKU_DIR/cache
ENV ENV_DIR=$HEROKU_DIR/env

# switch to root user, but no need to switch back as this image isn't run
USER root

# placeholder directories and files to emulate Heroku environment at slug compile time
RUN mkdir -p $APP_DIR $BUILDPACK_DIR $BUILD_DIR $CACHE_DIR $ENV_DIR \
 && mkdir -p $APP_DIR/foo \
 && touch $APP_DIR/foo/bar \
 && touch $APP_DIR/baz \
 && touch $APP_DIR/.qux

# set BUILD_DIR as working directory
# as this is where the "pushed" application files land
WORKDIR $BUILD_DIR
COPY test/init.R .

# ENV R_VERSION
ENV BUILDPACK_CLONE_URL=https://github.com/virtualstaticvoid/heroku-buildpack-r.git
ENV BUILDPACK_BRANCH=main
ENV BUILDPACK_VERSION=latest
ENV BUILDPACK_CACHE_KEY=default
ENV BUILDPACK_TEST=1

COPY test/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

VOLUME $APP_DIR
VOLUME $HEROKU_DIR
