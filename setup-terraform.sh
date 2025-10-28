#!/bin/bash

# Terraform-based Coder Server Setup with CORS Configuration
# This script sets up Coder server using Terraform with proper CORS settings

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🏗️ Setting up Coder server with Terraform and CORS configuration..."

# Load environment variables
source ./load-env.sh

# Convert .env to terraform.tfvars
echo "📋 Converting environment variables to Terraform configuration..."
./env-to-terraform.sh

# Initialize Terraform
echo "🔧 Initializing Terraform..."
terraform init

# Plan Terraform deployment
echo "📋 Planning Terraform deployment..."
terraform plan

# Apply Terraform configuration
echo "🚀 Applying Terraform configuration..."
terraform apply -auto-approve

# Wait for Coder server to start
echo "⏳ Waiting for Coder server to start..."
sleep 15

# Test CORS configuration
echo "🧪 Testing CORS configuration..."
./test-cors.sh

echo "✅ Terraform-based Coder setup completed!"
echo "🌐 Coder server is running at: $CODER_ACCESS_URL"
echo "🔗 Configure your Gerrit plugin with serverUrl = $CODER_ACCESS_URL"
