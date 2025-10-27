#!/bin/bash

set -euo pipefail

# Configurable settings
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODER_PORT=${CODER_PORT:-3000}
CODER_URL=${CODER_URL:-http://127.0.0.1:$CODER_PORT}
CODER_TEMPLATE_NAME=${CODER_TEMPLATE_NAME:-vscode-web}
CODER_TOKEN=${CODER_TOKEN:-}
CODER_TOKEN_VALUE=${CODER_SESSION_TOKEN:-${CODER_TOKEN:-}}

# Prepare a clean template directory in the container
docker exec coder-server rm -rf /tmp/template && docker exec coder-server mkdir -p /tmp/template

# Copy only the needed template file(s) into the clean directory
docker cp "$SCRIPT_DIR/code-server.tf" coder-server:/tmp/template/

# Set coder CLI path to /opt/coder (as found in container)
CODER_CLI="/opt/coder"
if ! docker exec coder-server test -x $CODER_CLI; then
  echo "ERROR: coder CLI not found at $CODER_CLI in container. Check your Coder image." >&2
  exit 1
fi

# Login and push template from the clean directory
docker exec -e CODER_SESSION_TOKEN="$CODER_TOKEN_VALUE" coder-server sh -lc \
  "$CODER_CLI login $CODER_URL --token \"\$CODER_SESSION_TOKEN\" >/dev/null && \
   $CODER_CLI templates push $CODER_TEMPLATE_NAME --directory /tmp/template --yes"

echo "Template '$CODER_TEMPLATE_NAME' pushed successfully!"
