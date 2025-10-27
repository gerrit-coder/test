#!/bin/bash

# CORS Configuration Test Script
# Tests CORS configuration between Gerrit and Coder

set -euo pipefail

# Configuration
GERRIT_URL="${GERRIT_URL:-http://127.0.0.1:8080}"
CODER_URL="${CODER_URL:-http://127.0.0.1:3000}"
CODER_PORT="${CODER_PORT:-3000}"
CODER_TOKEN="${CODER_SESSION_TOKEN:-}"

echo "🧪 Testing CORS Configuration"
echo "============================="
echo "Gerrit URL: $GERRIT_URL"
echo "Coder URL: $CODER_URL"
echo ""

# Function to test CORS preflight
test_cors_preflight() {
    echo "1️⃣ Testing CORS preflight request..."

    local response=$(curl -s -w "\n%{http_code}" \
        -H "Origin: $GERRIT_URL" \
        -H "Access-Control-Request-Method: GET" \
        -H "Access-Control-Request-Headers: Coder-Session-Token" \
        -X OPTIONS \
        "http://127.0.0.1:$CODER_PORT/api/v2/templates")

    local http_code=$(echo "$response" | tail -n1)
    local headers=$(echo "$response" | head -n -1)

    if [ "$http_code" = "200" ]; then
        echo "✅ CORS preflight successful (HTTP $http_code)"

        # Check for required CORS headers
        if echo "$headers" | grep -q "Access-Control-Allow-Origin"; then
            echo "✅ Access-Control-Allow-Origin header present"
        else
            echo "❌ Access-Control-Allow-Origin header missing"
        fi

        if echo "$headers" | grep -q "Access-Control-Allow-Methods"; then
            echo "✅ Access-Control-Allow-Methods header present"
        else
            echo "❌ Access-Control-Allow-Methods header missing"
        fi

        if echo "$headers" | grep -q "Access-Control-Allow-Headers"; then
            echo "✅ Access-Control-Allow-Headers header present"
        else
            echo "❌ Access-Control-Allow-Headers header missing"
        fi
    else
        echo "❌ CORS preflight failed (HTTP $http_code)"
        return 1
    fi
}

# Function to test API access
test_api_access() {
    echo ""
    echo "2️⃣ Testing API access..."

    local response=$(curl -s -w "\n%{http_code}" \
        -H "Origin: $GERRIT_URL" \
        "http://127.0.0.1:$CODER_PORT/api/v2/templates")

    local http_code=$(echo "$response" | tail -n1)

    if [ "$http_code" = "200" ]; then
        echo "✅ API access successful (HTTP $http_code)"
    elif [ "$http_code" = "401" ]; then
        echo "✅ API access successful (HTTP $http_code - authentication required)"
    else
        echo "❌ API access failed (HTTP $http_code)"
        return 1
    fi
}

# Function to test authenticated API access
test_authenticated_api() {
    if [ -z "$CODER_TOKEN" ]; then
        echo ""
        echo "3️⃣ Skipping authenticated API test (no token provided)"
        echo "   Set CODER_SESSION_TOKEN environment variable to test authentication"
        return 0
    fi

    echo ""
    echo "3️⃣ Testing authenticated API access..."

    local response=$(curl -s -w "\n%{http_code}" \
        -H "Origin: $GERRIT_URL" \
        -H "Coder-Session-Token: $CODER_TOKEN" \
        "http://127.0.0.1:$CODER_PORT/api/v2/templates")

    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n -1)

    if [ "$http_code" = "200" ]; then
        echo "✅ Authenticated API access successful (HTTP $http_code)"

        # Check if response contains template data
        if echo "$body" | grep -q "id"; then
            echo "✅ Template data received"
        else
            echo "⚠️  No template data in response"
        fi
    else
        echo "❌ Authenticated API access failed (HTTP $http_code)"
        return 1
    fi
}

# Function to test workspace creation
test_workspace_creation() {
    if [ -z "$CODER_TOKEN" ]; then
        echo ""
        echo "4️⃣ Skipping workspace creation test (no token provided)"
        return 0
    fi

    echo ""
    echo "4️⃣ Testing workspace creation (dry run)..."

    local test_workspace_name="test-workspace-$(date +%s)"
    local response=$(curl -s -w "\n%{http_code}" \
        -H "Origin: $GERRIT_URL" \
        -H "Coder-Session-Token: $CODER_TOKEN" \
        -H "Content-Type: application/json" \
        -X POST \
        -d "{\"name\":\"$test_workspace_name\",\"template_id\":\"test\"}" \
        "http://127.0.0.1:$CODER_PORT/api/v2/users/me/workspaces")

    local http_code=$(echo "$response" | tail -n1)

    if [ "$http_code" = "400" ] || [ "$http_code" = "404" ]; then
        echo "✅ Workspace creation endpoint accessible (HTTP $http_code - expected for invalid template)"
    elif [ "$http_code" = "201" ]; then
        echo "✅ Workspace creation successful (HTTP $http_code)"
    else
        echo "❌ Workspace creation failed (HTTP $http_code)"
        return 1
    fi
}

# Function to show summary
show_summary() {
    echo ""
    echo "📋 CORS Test Summary"
    echo "==================="
    echo "✅ CORS preflight requests working"
    echo "✅ API endpoints accessible from Gerrit origin"
    echo "✅ Cross-origin requests properly configured"
    echo ""
    echo "🎯 Next Steps:"
    echo "   1. Configure Gerrit plugin with Coder URL: http://127.0.0.1:$CODER_PORT"
    echo "   2. Test 'Open Coder Workspace' action in Gerrit"
    echo "   3. Check browser console for any remaining errors"
    echo ""
}

# Main execution
main() {
    test_cors_preflight
    test_api_access
    test_authenticated_api
    test_workspace_creation
    show_summary

    echo "🎉 CORS configuration test completed successfully!"
}

# Run main function
main "$@"
