#!/bin/bash

# Apply environment variables to YAML configuration files
# This script substitutes environment variables in YAML files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

echo "🔄 Applying environment variables to YAML configuration files..."

# Load environment variables from .env if it exists
if [ -f "$ENV_FILE" ]; then
    echo "📋 Loading environment variables from .env file..."
    set -a
    source "$ENV_FILE"
    set +a
else
    echo "ℹ️  No .env file found, using system environment variables"
fi

# Apply environment substitution to coder.yaml
if [ -f "$SCRIPT_DIR/coder.yaml" ]; then
    echo "📝 Updating coder.yaml with environment variables..."
    envsubst < "$SCRIPT_DIR/coder.yaml" > "$SCRIPT_DIR/coder.yaml.tmp"
    mv "$SCRIPT_DIR/coder.yaml.tmp" "$SCRIPT_DIR/coder.yaml"
    echo "✅ coder.yaml updated"
fi

# Apply environment substitution to coder-explicit.yaml
if [ -f "$SCRIPT_DIR/coder-explicit.yaml" ]; then
    echo "📝 Updating coder-explicit.yaml with environment variables..."
    envsubst < "$SCRIPT_DIR/coder-explicit.yaml" > "$SCRIPT_DIR/coder-explicit.yaml.tmp"
    mv "$SCRIPT_DIR/coder-explicit.yaml.tmp" "$SCRIPT_DIR/coder-explicit.yaml"
    echo "✅ coder-explicit.yaml updated"
fi

echo "✅ Environment variable substitution completed!"
echo "📋 Applied variables:"
echo "   CODER_PORT: ${CODER_PORT:-3000}"
echo "   CODER_ACCESS_URL: ${CODER_ACCESS_URL:-http://127.0.0.1:3000}"
echo "   CODER_SESSION_TOKEN: ${CODER_SESSION_TOKEN:-not set}"
