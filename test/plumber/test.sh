#!/bin/bash
set -e

export PORT=8080
R --no-save --gui-none -f app.R &

echo "Waiting for Shiny server..."
timeout 30s /bin/bash -c "while ! echo > /dev/tcp/localhost/${PORT}; do sleep 1; done"

echo "Running test..."
curl -v "localhost:${PORT}/echo?msg=Hello%20World!"
curl -v -d "a=10" -d "b=2" localhost:${PORT}/sum
curl -v "http://localhost:${PORT}/plot" -o plot.png
