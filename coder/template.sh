#!/bin/bash

set -euo pipefail

# Configurable settings
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODER_PORT=${CODER_PORT:-3000}
CODER_URL=${CODER_URL:-http://127.0.0.1:$CODER_PORT}
CODER_TEMPLATE_NAME=${CODER_TEMPLATE_NAME:-vscode-web}
CODER_TOKEN=${CODER_TOKEN:-}
CODER_TOKEN_VALUE=${CODER_SESSION_TOKEN:-${CODER_TOKEN:-}}

# Check if token is provided
if [ -z "$CODER_TOKEN_VALUE" ]; then
    echo "⚠️  No CODER_SESSION_TOKEN provided. Skipping template deployment."
    echo ""
    echo "   To deploy templates, you need a Coder session token:"
    echo "   1. Open Coder in your browser: $CODER_URL"
    echo "   2. Log in to Coder"
    echo "   3. Go to Settings > Account > Tokens"
    echo "   4. Create a new token"
    echo "   5. Set the token in one of these ways:"
    echo "      - Export: export CODER_SESSION_TOKEN=\"your-token\""
    echo "      - Add to .env: echo 'CODER_SESSION_TOKEN=\"your-token\"' >> .env"
    echo "   6. Then run: ./template.sh"
    echo ""
    echo "   Or run the complete setup: ./run.sh"
    exit 0
fi

echo "🚀 Deploying template '$CODER_TEMPLATE_NAME' to Coder..."

# Prepare a clean template directory in the container
docker exec coder-server rm -rf /tmp/template && docker exec coder-server mkdir -p /tmp/template

# Copy template file and terraform.tfvars (if exists) into the clean directory
docker cp "$SCRIPT_DIR/code-server.tf" coder-server:/tmp/template/
if [ -f "$SCRIPT_DIR/terraform.tfvars" ]; then
    docker cp "$SCRIPT_DIR/terraform.tfvars" coder-server:/tmp/template/
    echo "📋 Included terraform.tfvars (for variable defaults)"
fi

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
