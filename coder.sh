#!/bin/bash

set -euo pipefail

# https://coder.com/docs/install/docker
export CODER_DATA=$HOME/.config/coderv2-docker
export DOCKER_GROUP=$(getent group docker | cut -d: -f3)

# Configurable settings
CODER_PORT=${CODER_PORT:-3000}
CODER_ACCESS_URL=${CODER_ACCESS_URL:-http://127.0.0.1:$CODER_PORT}
CODER_URL=${CODER_URL:-http://127.0.0.1:$CODER_PORT}
CODER_TEMPLATE_NAME=${CODER_TEMPLATE_NAME:-vscode-web}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Starting Coder server with CORS configuration..."

mkdir -p $CODER_DATA

# Copy CORS configuration if it exists
if [ -f "$SCRIPT_DIR/coder.yaml" ]; then
    echo "📋 Copying CORS configuration..."
    cp "$SCRIPT_DIR/coder.yaml" "$CODER_DATA/coder.yaml"
else
    echo "⚠️  No coder.yaml found. CORS may not be configured."
    echo "   Run ./setup-cors.sh after starting Coder to configure CORS."
fi

# Start Coder server
docker run --rm -d \
  --name coder-server \
  -e CODER_HTTP_ADDRESS=0.0.0.0:$CODER_PORT \
  -e CODER_ACCESS_URL=$CODER_ACCESS_URL \
  -e CODER_TLS_ENABLE=false \
  -e CODER_TLS_ADDRESS=0.0.0.0:443 \
  -e CODER_REDIRECT_TO_ACCESS_URL=false \
  -v $CODER_DATA:/home/coder/.config \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add $DOCKER_GROUP \
  -p $CODER_PORT:$CODER_PORT \
  ghcr.io/coder/coder:latest

echo "✅ Coder server started!"
echo "🌐 Access URL: $CODER_ACCESS_URL"
echo "🔧 To configure CORS for Gerrit integration, run: ./setup-cors.sh"
