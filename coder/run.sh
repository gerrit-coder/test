#!/bin/bash

## Load environment variables
source ./load-env.sh

ensure_gerrit_ssh_key() {
    if [ -n "${GERRIT_SSH_PRIVATE_KEY:-}" ] || [ -n "${GERRIT_SSH_PRIVATE_KEY_B64:-}" ]; then
        echo "🔐 Using Gerrit SSH key from existing environment variables."
        return
    fi

    local key_path="${GERRIT_SSH_KEY_PATH:-$HOME/.ssh/gerrit_workspace_ed25519}"
    key_path="${key_path/#\~/$HOME}"
    mkdir -p "$(dirname "$key_path")"

    if [ ! -f "$key_path" ]; then
        echo "🔐 Generating persistent Gerrit SSH key at $key_path..."
        if ! ssh-keygen -t ed25519 -N "" -f "$key_path"; then
            echo "❌ Failed to generate SSH key. Install openssh-client/ssh-keygen and retry." >&2
            exit 1
        fi
        echo ""
        echo "📋 Public key (add this to Gerrit → Settings → SSH Public Keys):"
        cat "$key_path.pub"
        echo ""
        echo "   After the key is registered in Gerrit, rerun this script so the workspace template"
        echo "   can reuse the same credentials."
    else
        echo "🔐 Reusing Gerrit SSH key at $key_path"
    fi

    if ! command -v base64 >/dev/null 2>&1; then
        echo "❌ 'base64' command not found. Install coreutils (or equivalent) and retry." >&2
        exit 1
    fi

    export GERRIT_SSH_KEY_PATH="$key_path"
    GERRIT_SSH_PRIVATE_KEY_B64="$(base64 < "$key_path" | tr -d '\n')"
    export GERRIT_SSH_PRIVATE_KEY_B64
    echo "✅ Exported GERRIT_SSH_PRIVATE_KEY_B64 for Terraform template ingestion."
}

ensure_gerrit_ssh_key

# Check if .env file exists, if not, create one from template
if [ ! -f ".env" ]; then
    echo "📋 Creating .env file from env.example template..."
    cp env.example .env
    echo "✅ Created .env file. Please edit it with your configuration."
    echo "   Important: Set CODER_SESSION_TOKEN in .env for template deployment"
    echo ""
    echo "   Edit .env file now, then press Enter to continue..."
    read -r
fi

echo "🚀 Starting complete Coder-Gerrit integration setup..."

# Step 1: Apply environment variables to YAML files
echo "📋 Applying environment variables to YAML configuration files..."
./apply-env-to-yaml.sh

# Step 2: Convert .env to terraform.tfvars
echo "📋 Converting environment variables to Terraform configuration..."
./env-to-terraform.sh

# Step 3: Start Coder server
echo "🐳 Starting Coder server..."
./coder.sh

# Step 4: Wait for Coder API to be ready
echo "⏳ Waiting for Coder API to be ready..."

# Wait until Coder responds (200/401) to avoid "container not running" races
attempt=0
until code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${CODER_PORT:-3000}/api/v2/templates"); do
  :
done
while ! echo "$code" | grep -qE '^(200|401)$'; do
  if [ $attempt -gt 30 ]; then
    echo "❌ Coder did not become ready in time (last HTTP $code)" >&2
    break
  fi
  attempt=$((attempt+1))
  echo "⏳ Waiting for Coder API (HTTP $code)..."
  sleep 2
  code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${CODER_PORT:-3000}/api/v2/templates")
done

# Step 5: Deploy template to Coder
echo "🏗️ Deploying template to Coder..."

# Check if CODER_SESSION_TOKEN is available
if [ -z "${CODER_SESSION_TOKEN:-}" ]; then
    echo "⚠️  No CODER_SESSION_TOKEN found. Template deployment requires authentication."
    echo "   To get a session token:"
    echo "   1. Open Coder in your browser: $CODER_ACCESS_URL"
    echo "   2. Log in to Coder"
    echo "   3. Go to Settings > Account > Tokens"
    echo "   4. Create a new token and set it as CODER_SESSION_TOKEN"
    echo "   5. Run: export CODER_SESSION_TOKEN=\"your-token\""
    echo "   6. Then run: ./template.sh"
    echo ""
    echo "   Or create a .env file with your token:"
    echo "   echo 'CODER_SESSION_TOKEN=\"your-token\"' >> .env"
    echo ""
    echo "✅ Coder server is running at: $CODER_ACCESS_URL"
    echo "🔗 Configure your Gerrit plugin with serverUrl = $CODER_ACCESS_URL"
    exit 0
fi

# Deploy template using template.sh
echo "📋 Deploying template using template.sh..."
./template.sh

echo "🎉 Setup complete! Coder is running at: $CODER_ACCESS_URL"
echo "🔗 Configure your Gerrit plugin with serverUrl = $CODER_ACCESS_URL"
echo ""
echo "📋 Next steps:"
echo "   1. Configure Gerrit plugin with serverUrl = $CODER_ACCESS_URL"
echo "   2. Test 'Open Coder Workspace' action in Gerrit"
