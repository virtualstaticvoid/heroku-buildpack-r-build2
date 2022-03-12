#!/bin/bash

set -e # fail-fast

# ensure expected directories
mkdir -p $BUILDPACK_DIR $BUILD_DIR $CACHE_DIR $ENV_DIR

# enter buildpack directory (Heroku does this step)
# and clone the buildpack sources
echo
echo "Cloning ${BUILDPACK_CLONE_URL}#${BUILDPACK_BRANCH}..."
cd $BUILDPACK_DIR
git clone --branch $BUILDPACK_BRANCH --depth=1 --quiet $BUILDPACK_CLONE_URL .
echo "Using version: $(git rev-parse HEAD)"

# enter build directory (which is working directory during slug compilation)
cd $BUILD_DIR

# emulate detection
echo
echo "Detection..."
$BUILDPACK_DIR/bin/detect "$BUILD_DIR"

# emulate slug compilation
echo
echo "Slug compilation..."
$BUILDPACK_DIR/bin/compile "$BUILD_DIR" "$CACHE_DIR" "$ENV_DIR"

# set the environment from compile outputs
source $BUILD_DIR/.profile.d/heroku-buildpack-r-env.sh

# run the provided test script
echo
echo "Testing application..."
cd $APP_DIR
./test.sh
