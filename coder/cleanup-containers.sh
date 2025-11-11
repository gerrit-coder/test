#!/bin/bash

# Cleanup script for conflicting Docker containers
# This script removes containers that might conflict with Terraform deployment

set -euo pipefail

echo "🧹 Cleaning up conflicting Docker containers..."

# Remove containers with coder-gerrit-coder pattern
echo "📋 Removing containers with 'coder-gerrit-coder' pattern..."
docker ps -a --filter "name=coder-gerrit-coder" --format "{{.Names}}" | while read -r container; do
    if [ -n "$container" ]; then
        echo "🗑️  Removing container: $container"
        docker rm -f "$container" || echo "⚠️  Failed to remove $container (may not exist)"
    fi
done

# Remove any containers with coder-workspace pattern
echo "📋 Removing containers with 'coder-workspace' pattern..."
docker ps -a --filter "name=coder-workspace" --format "{{.Names}}" | while read -r container; do
    if [ -n "$container" ]; then
        echo "🗑️  Removing container: $container"
        docker rm -f "$container" || echo "⚠️  Failed to remove $container (may not exist)"
    fi
done

echo "✅ Container cleanup completed!"
echo ""
echo "🚀 You can now run:"
echo "   terraform apply -auto-approve"
echo "   or"
echo "   ./run.sh"
