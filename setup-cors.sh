#!/bin/bash

# Coder CORS Configuration Setup Script
# This script helps configure Coder with proper CORS settings for Gerrit integration

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODER_CONFIG_FILE="$SCRIPT_DIR/coder.yaml"
CODER_CONTAINER_NAME="coder-server"
GERRIT_URL="${GERRIT_URL:-http://127.0.0.1:8080}"
CODER_PORT="${CODER_PORT:-3000}"

echo "🔧 Setting up Coder CORS configuration for Gerrit integration..."

# Function to check if Coder container is running
check_coder_running() {
    if ! docker ps --format "table {{.Names}}" | grep -q "^${CODER_CONTAINER_NAME}$"; then
        echo "❌ Coder container '$CODER_CONTAINER_NAME' is not running."
        echo "   Please start Coder first using: ./coder.sh"
        exit 1
    fi
    echo "✅ Coder container is running"
}

# Function to update CORS configuration in coder.yaml
update_cors_config() {
    echo "📝 Updating CORS configuration..."

    # Create backup of existing config if it exists
    if [ -f "$CODER_CONFIG_FILE" ]; then
        cp "$CODER_CONFIG_FILE" "${CODER_CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        echo "📋 Created backup of existing configuration"
    fi

    # Create a temporary config file with environment variable substitution
    local temp_config=$(mktemp)
    env GERRIT_URL="$GERRIT_URL" CODER_PORT="$CODER_PORT" \
        envsubst < "$CODER_CONFIG_FILE" > "$temp_config"

    # Replace the original config with the substituted version
    mv "$temp_config" "$CODER_CONFIG_FILE"
    echo "✅ Updated configuration with Gerrit URL: $GERRIT_URL and Coder port: $CODER_PORT"
}

# Function to apply CORS configuration
apply_cors_config() {
    echo "🚀 Applying CORS configuration to Coder..."

    # Copy configuration file to container
    docker cp "$CODER_CONFIG_FILE" "$CODER_CONTAINER_NAME:/home/coder/.config/coder.yaml"

    # Restart Coder to apply new configuration
    echo "🔄 Restarting Coder to apply CORS settings..."
    docker restart "$CODER_CONTAINER_NAME"

    # Wait for Coder to start up
    echo "⏳ Waiting for Coder to start up..."
    sleep 10

    # Check if Coder is responding
    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        # Check if Coder is responding (401 is expected for unauthenticated requests)
        local response_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$CODER_PORT/api/v2/templates")
        if [ "$response_code" = "200" ] || [ "$response_code" = "401" ]; then
            echo "✅ Coder is responding successfully (HTTP $response_code)"
            break
        fi

        if [ $attempt -eq $max_attempts ]; then
            echo "❌ Coder failed to start after $max_attempts attempts (last response: HTTP $response_code)"
            echo "   Check logs with: docker logs $CODER_CONTAINER_NAME"
            exit 1
        fi

        echo "⏳ Attempt $attempt/$max_attempts: Waiting for Coder... (response: HTTP $response_code)"
        sleep 2
        attempt=$((attempt + 1))
    done
}

# Function to test CORS configuration
test_cors_config() {
    echo "🧪 Testing CORS configuration..."

    # Test CORS preflight request
    local cors_test=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Origin: $GERRIT_URL" \
        -H "Access-Control-Request-Method: GET" \
        -H "Access-Control-Request-Headers: Coder-Session-Token" \
        -X OPTIONS \
        "http://localhost:$CODER_PORT/api/v2/templates")

    if [ "$cors_test" = "200" ]; then
        echo "✅ CORS preflight request successful"
    else
        echo "❌ CORS preflight request failed (HTTP $cors_test)"
        echo "   Check Coder logs: docker logs $CODER_CONTAINER_NAME"
        return 1
    fi

    # Test actual API request
    local api_test=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Origin: $GERRIT_URL" \
        "http://localhost:$CODER_PORT/api/v2/templates")

    if [ "$api_test" = "200" ] || [ "$api_test" = "401" ]; then
        echo "✅ CORS API request successful (HTTP $api_test)"
    else
        echo "❌ CORS API request failed (HTTP $api_test)"
        return 1
    fi
}

# Function to show configuration summary
show_summary() {
    echo ""
    echo "📋 CORS Configuration Summary:"
    echo "   Gerrit URL: $GERRIT_URL"
    echo "   Coder URL: http://localhost:$CODER_PORT"
    echo "   Config file: $CODER_CONFIG_FILE"
    echo ""
    echo "🔗 Next steps:"
    echo "   1. Configure your Gerrit plugin with:"
    echo "      serverUrl = http://127.0.0.1:$CODER_PORT"
    echo "   2. Test the 'Open Coder Workspace' action in Gerrit"
    echo "   3. Check browser console for any remaining CORS errors"
    echo ""
}

# Main execution
main() {
    echo "🎯 Coder CORS Configuration for Gerrit Integration"
    echo "=================================================="

    check_coder_running
    update_cors_config
    apply_cors_config
    test_cors_config
    show_summary

    echo "🎉 CORS configuration completed successfully!"
}

# Run main function
main "$@"
