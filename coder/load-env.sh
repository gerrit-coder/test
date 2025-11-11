#!/bin/bash

# Environment Configuration Loader
# This script loads environment variables from a .env file if it exists

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# Load environment variables from .env file if it exists
if [ -f "$ENV_FILE" ]; then
    echo "📋 Loading environment variables from .env file..."
    # Export variables from .env file
    set -a  # automatically export all variables
    source "$ENV_FILE"
    set +a  # disable automatic export
    echo "✅ Environment variables loaded"
else
    echo "ℹ️  No .env file found, using default values"
    echo "   Copy env.example to .env and customize for your environment"
fi

# Display current configuration
echo ""
echo "🔧 Current Configuration:"
echo "   GERRIT_URL: ${GERRIT_URL:-http://127.0.0.1:8080}"
echo "   CODER_PORT: ${CODER_PORT:-3000}"
echo "   CODER_ACCESS_URL: ${CODER_ACCESS_URL:-http://127.0.0.1:3000}"
echo "   CODER_URL: ${CODER_URL:-http://127.0.0.1:3000}"
echo "   CODER_TEMPLATE_NAME: ${CODER_TEMPLATE_NAME:-vscode-web}"
echo "   CODER_SESSION_TOKEN: ${CODER_SESSION_TOKEN:-not set}"
echo ""
