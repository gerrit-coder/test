#!/bin/bash

## Load environment variables
source ./load-env.sh

echo "🚀 Starting complete Coder-Gerrit integration setup with nginx proxy..."

# Step 1: Apply environment variables to YAML files
echo "📋 Applying environment variables to YAML configuration files..."
./apply-env-to-yaml.sh

# Step 2: Convert .env to terraform.tfvars
echo "📋 Converting environment variables to Terraform configuration..."
./env-to-terraform.sh

# Step 3: Setup nginx proxy with Coder server (handles CORS automatically)
echo "🔧 Setting up nginx proxy with Coder server..."
./setup-nginx.sh

# Step 4: Deploy template to Coder
echo "🏗️ Deploying template to Coder..."
if [ -n "$CODER_SESSION_TOKEN" ]; then
    echo "📋 Using Coder session token for template deployment..."
    ./template.sh
else
    echo "⚠️  No CODER_SESSION_TOKEN provided. Skipping template deployment."
    echo "   To deploy templates, set CODER_SESSION_TOKEN in your .env file:"
    echo "   CODER_SESSION_TOKEN=\"your-coder-session-token\""
    echo "   Then run: ./template.sh"
fi

echo "🎉 Setup complete! Coder is running with nginx proxy at: $CODER_PROXY_URL"
echo "🔗 Configure your Gerrit plugin with serverUrl = $CODER_PROXY_URL"
echo ""
echo "🧪 Test nginx proxy CORS configuration:"
echo "   ./test-nginx-cors.sh"
echo ""
echo "📋 Next steps:"
echo "   1. Configure Gerrit plugin with serverUrl = $CODER_PROXY_URL"
echo "   2. Test 'Open Coder Workspace' action in Gerrit"
echo "   3. Check browser console for any remaining errors"
echo ""
echo "💡 Architecture: Gerrit (8080) → Nginx Proxy (3001) → Coder (3000)"
echo "   - Direct Coder URL: $CODER_ACCESS_URL"
echo "   - Proxy URL (use this): $CODER_PROXY_URL"
