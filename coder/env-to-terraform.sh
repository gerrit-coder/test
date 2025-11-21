#!/bin/bash

# Convert .env file to terraform.tfvars
# This script reads .env file and creates terraform.tfvars with proper formatting

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
TFVARS_FILE="$SCRIPT_DIR/terraform.tfvars"

echo "🔄 Converting .env file to terraform.tfvars..."

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ .env file not found at $ENV_FILE"
    echo "   Please create .env file first or copy from env.example"
    exit 1
fi

# Load environment variables from .env
set -a
source "$ENV_FILE"
set +a

# Create terraform.tfvars file
cat > "$TFVARS_FILE" << EOF
# terraform.tfvars - Generated from .env file
# Generated on: $(date)

# Server Configuration - Uses CODER_ACCESS_URL from environment
coder_http_address = "0.0.0.0:${CODER_PORT:-3000}"
coder_access_url = "${CODER_ACCESS_URL:-http://127.0.0.1:3000}"
coder_tls_enable = "false"
coder_redirect_to_access_url = "false"

# Integration Configuration - Uses GERRIT_URL from environment
gerrit_url = "${GERRIT_URL:-http://127.0.0.1:8080}"
coder_port = "${CODER_PORT:-3000}"
coder_session_token = "${CODER_SESSION_TOKEN:-}"
EOF

# Append optional Gerrit SSH key material if provided
if [ -n "${GERRIT_SSH_PRIVATE_KEY:-}" ]; then
    {
        echo ""
        echo "gerrit_ssh_private_key = <<EOKEY"
        printf "%s\n" "${GERRIT_SSH_PRIVATE_KEY}"
        echo "EOKEY"
    } >> "$TFVARS_FILE"
elif [ -n "${GERRIT_SSH_PRIVATE_KEY_B64:-}" ]; then
    {
        echo ""
        printf 'gerrit_ssh_private_key_b64 = "%s"\n' "${GERRIT_SSH_PRIVATE_KEY_B64}"
    } >> "$TFVARS_FILE"
fi

echo "✅ terraform.tfvars created successfully!"
echo "📋 Generated variables:"
echo "   GERRIT_URL: ${GERRIT_URL:-http://127.0.0.1:8080}"
echo "   CODER_PORT: ${CODER_PORT:-3000}"
echo "   CODER_ACCESS_URL: ${CODER_ACCESS_URL:-http://127.0.0.1:3000}"
echo "   CODER_SESSION_TOKEN: ${CODER_SESSION_TOKEN:-not set}"
echo ""
echo "🚀 Next steps:"
echo "   1. Run: terraform init"
echo "   2. Run: terraform plan"
echo "   3. Run: terraform apply"
