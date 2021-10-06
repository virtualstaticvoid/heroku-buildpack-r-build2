#!/bin/bash

set -e # fail-fast

# ensure expected directories in /heroku volume
mkdir -p $BUILDPACK_DIR $BUILD_DIR $CACHE_DIR $ENV_DIR

# enter buildpack directory (Heroku does this step)
# and clone the buildpack sources
echo
echo "Cloning ${BUILDPACK_CLONE_URL}#${BUILDPACK_BRANCH}..."
cd /heroku/buildpack
git clone --branch $BUILDPACK_BRANCH --depth=1 --quiet $BUILDPACK_CLONE_URL .
echo "Using version: $(git rev-parse HEAD)"

# enter build directory (which is working directory during slug compilation)
# and emulate slug compilation
echo
echo "Starting slug compilation..."
cd /heroku/build
/heroku/buildpack/bin/compile "$BUILD_DIR" "$CACHE_DIR" "$ENV_DIR"

# test.sh file present?
echo
echo "Testing application..."
source $BUILD_DIR/.profile.d/heroku-buildpack-r-env.sh
cd /app
./test.sh
