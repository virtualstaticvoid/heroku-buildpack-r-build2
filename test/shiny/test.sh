#!/bin/bash
set -e

export PORT=8080
R --no-save --gui-none -f run.R &

echo "Waiting for Shiny server..."
timeout 30s /bin/bash -c "while ! echo > /dev/tcp/localhost/${PORT}; do sleep 1; done"

echo "Running test..."
curl -v localhost:${PORT}
