#!/bin/bash

set -e # fail-fast

debug_break() {
  echo $1
  if [ ! -z ${BUILDPACK_TEST_DEBUG+x} ] && [ "$BUILDPACK_TEST_DEBUG" == "1" ]; then
    echo
    echo "$1"
    echo
    echo " 👉 Starting debugging session..."
    echo "         ... exit to continue ..."
    echo
    /bin/bash -l
    echo
    echo "Continuing..."
    echo
  fi
}

if [ ! -z ${BUILDPACK_TEST_DEBUG+x} ] && [ "$BUILDPACK_TEST_DEBUG" == "1" ]; then
  trap "debug_break" ERR
fi


# ensure expected directories
mkdir -p $BUILDPACK_DIR $BUILD_DIR $CACHE_DIR $ENV_DIR

# get buildpack sources
echo
(
  cd $BUILDPACK_DIR
  git config --global --add safe.directory $(pwd)

  if [ ! -d .git ]; then
    # clone the buildpack sources
    echo "Cloning ${BUILDPACK_CLONE_URL}#${BUILDPACK_BRANCH}..."
    git clone --branch $BUILDPACK_BRANCH --depth=1 --quiet $BUILDPACK_CLONE_URL .
  fi
  echo "Using version: $(git rev-parse HEAD)"
)

# enter build directory (which is working directory during slug compilation)
echo
(
  cd $BUILD_DIR

  # emulate detection
  echo "Detection..."
  $BUILDPACK_DIR/bin/detect "$BUILD_DIR"

  # emulate slug compilation
  debug_break "Slug compilation..."
  $BUILDPACK_DIR/bin/compile "$BUILD_DIR" "$CACHE_DIR" "$ENV_DIR"
)

# set the environment from compile outputs
source $BUILD_DIR/.profile.d/heroku-buildpack-r-env.sh

# run tests
echo
(
  cd $APP_DIR

  # run the provided test script
  debug_break "Testing application..."
  ./test.sh
)
