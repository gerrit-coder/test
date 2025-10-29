#!/bin/bash

# Test script for nginx proxy CORS configuration
# This script tests the nginx proxy setup for Coder-Gerrit integration

set -euo pipefail

# Configuration
GERRIT_URL="${GERRIT_URL:-http://127.0.0.1:8080}"
NGINX_PORT="${NGINX_PORT:-3001}"
CODER_PORT="${CODER_PORT:-3000}"

echo "🧪 Testing nginx proxy CORS configuration..."

# Function to test direct Coder access (should fail with CORS)
test_direct_coder() {
    echo "📡 Testing direct Coder access (should show CORS issues)..."

    local cors_test=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Origin: $GERRIT_URL" \
        -H "Access-Control-Request-Method: GET" \
        -H "Access-Control-Request-Headers: Coder-Session-Token" \
        -X OPTIONS \
        "http://localhost:$CODER_PORT/api/v2/templates")

    echo "   Direct Coder CORS preflight: HTTP $cors_test"

    local api_test=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Origin: $GERRIT_URL" \
        "http://localhost:$CODER_PORT/api/v2/templates")

    echo "   Direct Coder API request: HTTP $api_test"
}

# Function to test nginx proxy access (should work with CORS)
test_nginx_proxy() {
    echo "🔗 Testing nginx proxy access (should work with CORS)..."

    # Test CORS preflight request through nginx
    local cors_test=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Origin: $GERRIT_URL" \
        -H "Access-Control-Request-Method: GET" \
        -H "Access-Control-Request-Headers: Coder-Session-Token" \
        -X OPTIONS \
        "http://localhost:$NGINX_PORT/api/v2/templates")

    echo "   Nginx proxy CORS preflight: HTTP $cors_test"

    if [ "$cors_test" = "200" ] || [ "$cors_test" = "204" ]; then
        echo "   ✅ CORS preflight successful"
    else
        echo "   ❌ CORS preflight failed"
    fi

    # Test actual API request through nginx
    local api_test=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Origin: $GERRIT_URL" \
        "http://localhost:$NGINX_PORT/api/v2/templates")

    echo "   Nginx proxy API request: HTTP $api_test"

    if [ "$api_test" = "200" ] || [ "$api_test" = "401" ]; then
        echo "   ✅ API request successful"
    else
        echo "   ❌ API request failed"
    fi
}

# Function to test CORS headers
test_cors_headers() {
    echo "📋 Testing CORS headers..."

    local response=$(curl -s -I \
        -H "Origin: $GERRIT_URL" \
        "http://localhost:$NGINX_PORT/api/v2/templates")

    echo "   Response headers:"
    echo "$response" | grep -i "access-control" | sed 's/^/     /'
}

# Function to test health endpoint
test_health_endpoint() {
    echo "🏥 Testing nginx health endpoint..."

    local health_response=$(curl -s -o /dev/null -w "%{http_code}" \
        "http://localhost:$NGINX_PORT/health")

    if [ "$health_response" = "200" ]; then
        echo "   ✅ Health endpoint responding (HTTP $health_response)"
    else
        echo "   ❌ Health endpoint failed (HTTP $health_response)"
    fi
}

# Function to show detailed CORS test
show_detailed_cors_test() {
    echo "🔍 Detailed CORS test with headers..."

    echo "   Testing OPTIONS request:"
    curl -v \
        -H "Origin: $GERRIT_URL" \
        -H "Access-Control-Request-Method: GET" \
        -H "Access-Control-Request-Headers: Coder-Session-Token" \
        -X OPTIONS \
        "http://localhost:$NGINX_PORT/api/v2/templates" 2>&1 | grep -E "(< HTTP|< Access-Control|> Origin|> Access-Control)"

    echo ""
    echo "   Testing GET request:"
    curl -v \
        -H "Origin: $GERRIT_URL" \
        "http://localhost:$NGINX_PORT/api/v2/templates" 2>&1 | grep -E "(< HTTP|< Access-Control|> Origin)" | head -10
}

# Function to show configuration summary
show_summary() {
    echo ""
    echo "📋 Test Summary:"
    echo "   Gerrit URL: $GERRIT_URL"
    echo "   Coder Direct: http://localhost:$CODER_PORT"
    echo "   Coder Proxy: http://localhost:$NGINX_PORT"
    echo ""
    echo "🔗 For Gerrit plugin configuration, use:"
    echo "   serverUrl = http://localhost:$NGINX_PORT"
    echo ""
    echo "📊 To view logs:"
    echo "   docker logs nginx-coder-proxy"
    echo "   docker logs coder-server"
}

# Main execution
main() {
    echo "🎯 Nginx Proxy CORS Test"
    echo "========================"

    test_health_endpoint
    test_direct_coder
    test_nginx_proxy
    test_cors_headers
    show_detailed_cors_test
    show_summary

    echo ""
    echo "🎉 CORS testing completed!"
}

# Run main function
main "$@"
