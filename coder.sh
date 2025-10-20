#!/bin/bash

set -euo pipefail

# https://coder.com/docs/install/docker
export CODER_DATA=$HOME/.config/coderv2-docker
export DOCKER_GROUP=$(getent group docker | cut -d: -f3)

# Configurable settings
CODER_ACCESS_URL=https://your-coder.com:3000
CODER_URL=${CODER_URL:-http://127.0.0.1:3000}
CODER_TEMPLATE_NAME=${CODER_TEMPLATE_NAME:-vscode-web}

mkdir -p $CODER_DATA

# Start Coder server
docker run --rm -d \
  --name coder-server \
  -e CODER_HTTP_ADDRESS=0.0.0.0:3000 \
  -e CODER_ACCESS_URL=$CODER_ACCESS_URL \
  -e CODER_TLS_ENABLE=false \
  -e CODER_TLS_ADDRESS=0.0.0.0:443 \
  -e CODER_REDIRECT_TO_ACCESS_URL=false \
  -v $CODER_DATA:/home/coder/.config \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add $DOCKER_GROUP \
  -p 3000:3000 \
  ghcr.io/coder/coder:latest
