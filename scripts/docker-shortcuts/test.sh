#!/usr/bin/env bash

# Generate up-to-date test interface
echo "👾 Generate up-to-date test interface"
swift test --generate-linuxmain

# Build
echo "🤖 Build"
docker build -f ./docker/test/Dockerfile -t xmlcoding .

# Run
echo "🏃‍♀️ Run"
docker run xmlcoding
