#!/bin/bash

## Load environment variables
source ./load-env.sh

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

# Step 4: Setup CORS configuration (wait until Coder API is ready)
echo "🔧 Setting up CORS configuration..."

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

./setup-cors.sh

# Step 5: Deploy template with Terraform
echo "🏗️ Deploying template with Terraform..."
if [ -f "terraform.tfvars" ]; then
    echo "📋 Using terraform.tfvars for configuration..."
    if command -v terraform >/dev/null 2>&1; then
        terraform init
        terraform plan
        terraform apply -auto-approve
    else
        echo "⚠️  Terraform not found. Installing Terraform..."
        echo "📦 Installing Terraform via snap..."

        # Install Terraform using snap
        if command -v snap >/dev/null 2>&1; then
            sudo snap install terraform --classic
            echo "✅ Terraform installed successfully!"

            # Initialize and apply Terraform
            terraform init
            terraform plan
            terraform apply -auto-approve
        else
            echo "❌ Snap not available. Please install Terraform manually:"
            echo "   curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -"
            echo "   sudo apt-add-repository \"deb [arch=amd64] https://apt.releases.hashicorp.com \$(lsb_release -cs) main\""
            echo "   sudo apt-get update && sudo apt-get install terraform"
            echo ""
            echo "   Or use: ./template.sh (fallback option)"
        fi
    fi
else
    echo "⚠️ terraform.tfvars not found, using default template deployment..."
    ./template.sh
fi

echo "🎉 Setup complete! Coder is running at: $CODER_ACCESS_URL"
echo "🔗 Configure your Gerrit plugin with serverUrl = $CODER_ACCESS_URL"
echo ""
echo "🧪 Test CORS configuration:"
echo "   ./test-cors.sh"
echo ""
echo "📋 Next steps:"
echo "   1. Configure Gerrit plugin with serverUrl = $CODER_ACCESS_URL"
echo "   2. Test 'Open Coder Workspace' action in Gerrit"
echo "   3. Check browser console for any remaining errors"
