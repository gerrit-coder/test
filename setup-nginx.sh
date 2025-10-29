#!/bin/bash

# Nginx-based CORS solution for Coder-Gerrit integration
# This script sets up nginx as a reverse proxy to handle CORS between Gerrit and Coder

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GERRIT_URL="${GERRIT_URL:-http://127.0.0.1:8080}"
CODER_PORT="${CODER_PORT:-3000}"
NGINX_PORT="${NGINX_PORT:-3001}"
CODER_ACCESS_URL="${CODER_ACCESS_URL:-http://127.0.0.1:3000}"

echo "🔧 Setting up nginx reverse proxy for Coder-Gerrit CORS integration..."

# Function to check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        echo "❌ Docker is not running. Please start Docker first."
        exit 1
    fi
    echo "✅ Docker is running"
}

# Function to stop existing containers
stop_existing_containers() {
    echo "🛑 Stopping existing containers..."

    # Stop nginx proxy if running
    if docker ps -q -f name=nginx-coder-proxy | grep -q .; then
        docker stop nginx-coder-proxy
        docker rm nginx-coder-proxy
        echo "✅ Stopped existing nginx proxy"
    fi

    # Stop coder-server if running
    if docker ps -q -f name=coder-server | grep -q .; then
        docker stop coder-server
        docker rm coder-server
        echo "✅ Stopped existing coder server"
    fi
}

# Function to update nginx configuration with environment variables
update_nginx_config() {
    echo "📝 Updating nginx configuration..."

    # Create a temporary nginx config with environment variable substitution
    local temp_config=$(mktemp)
    env GERRIT_URL="$GERRIT_URL" CODER_PORT="$CODER_PORT" NGINX_PORT="$NGINX_PORT" \
        envsubst < "$SCRIPT_DIR/nginx.conf" > "$temp_config"

    # Replace the original config with the substituted version
    mv "$temp_config" "$SCRIPT_DIR/nginx.conf"
    echo "✅ Updated nginx configuration"
}

# Function to start services with Docker Compose
start_services() {
    echo "🐳 Starting services with Docker Compose..."

    # Update docker-compose.yml with environment variables
    local temp_compose=$(mktemp)
    env CODER_PORT="$CODER_PORT" NGINX_PORT="$NGINX_PORT" CODER_ACCESS_URL="$CODER_ACCESS_URL" \
        envsubst < "$SCRIPT_DIR/docker-compose.yml" > "$temp_compose"
    mv "$temp_compose" "$SCRIPT_DIR/docker-compose.yml"

    # Start services
    cd "$SCRIPT_DIR"
    docker-compose up -d

    echo "✅ Services started successfully"
}

# Function to wait for services to be ready
wait_for_services() {
    echo "⏳ Waiting for services to be ready..."

    # Wait for Coder
    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        local coder_response=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$CODER_PORT/api/v2/templates")
        if [ "$coder_response" = "200" ] || [ "$coder_response" = "401" ]; then
            echo "✅ Coder is responding (HTTP $coder_response)"
            break
        fi

        if [ $attempt -eq $max_attempts ]; then
            echo "❌ Coder failed to start after $max_attempts attempts (last response: HTTP $coder_response)"
            echo "   Check logs with: docker logs coder-server"
            exit 1
        fi

        echo "⏳ Attempt $attempt/$max_attempts: Waiting for Coder... (response: HTTP $coder_response)"
        sleep 2
        attempt=$((attempt + 1))
    done

    # Wait for nginx
    attempt=1
    while [ $attempt -le $max_attempts ]; do
        local nginx_response=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$NGINX_PORT/health")
        if [ "$nginx_response" = "200" ]; then
            echo "✅ Nginx proxy is responding (HTTP $nginx_response)"
            break
        fi

        if [ $attempt -eq $max_attempts ]; then
            echo "❌ Nginx proxy failed to start after $max_attempts attempts (last response: HTTP $nginx_response)"
            echo "   Check logs with: docker logs nginx-coder-proxy"
            exit 1
        fi

        echo "⏳ Attempt $attempt/$max_attempts: Waiting for nginx... (response: HTTP $nginx_response)"
        sleep 2
        attempt=$((attempt + 1))
    done
}

# Function to test CORS through nginx proxy
test_cors_proxy() {
    echo "🧪 Testing CORS through nginx proxy..."

    # Test CORS preflight request through nginx
    local cors_test=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Origin: $GERRIT_URL" \
        -H "Access-Control-Request-Method: GET" \
        -H "Access-Control-Request-Headers: Coder-Session-Token" \
        -X OPTIONS \
        "http://localhost:$NGINX_PORT/api/v2/templates")

    if [ "$cors_test" = "200" ] || [ "$cors_test" = "204" ]; then
        echo "✅ CORS preflight request through nginx successful (HTTP $cors_test)"
    else
        echo "❌ CORS preflight request through nginx failed (HTTP $cors_test)"
        echo "   Check nginx logs: docker logs nginx-coder-proxy"
        return 1
    fi

    # Test actual API request through nginx
    local api_test=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Origin: $GERRIT_URL" \
        "http://localhost:$NGINX_PORT/api/v2/templates")

    if [ "$api_test" = "200" ] || [ "$api_test" = "401" ]; then
        echo "✅ CORS API request through nginx successful (HTTP $api_test)"
    else
        echo "❌ CORS API request through nginx failed (HTTP $api_test)"
        return 1
    fi
}

# Function to show configuration summary
show_summary() {
    echo ""
    echo "📋 Nginx Proxy Configuration Summary:"
    echo "   Gerrit URL: $GERRIT_URL"
    echo "   Coder Direct URL: http://localhost:$CODER_PORT"
    echo "   Coder Proxy URL: http://localhost:$NGINX_PORT"
    echo "   Nginx Config: $SCRIPT_DIR/nginx.conf"
    echo "   Docker Compose: $SCRIPT_DIR/docker-compose.yml"
    echo ""
    echo "🔗 Next steps:"
    echo "   1. Configure your Gerrit plugin with:"
    echo "      serverUrl = http://localhost:$NGINX_PORT"
    echo "      # Or use environment variable: serverUrl = $CODER_PROXY_URL"
    echo "   2. Test the 'Open Coder Workspace' action in Gerrit"
    echo "   3. Check browser console for any remaining CORS errors"
    echo ""
    echo "🧪 Test CORS configuration:"
    echo "   curl -H \"Origin: $GERRIT_URL\" -X OPTIONS http://localhost:$NGINX_PORT/api/v2/templates"
    echo ""
}

# Function to show logs
show_logs() {
    echo "📋 Container logs:"
    echo ""
    echo "=== Coder Server Logs ==="
    docker logs coder-server --tail 20
    echo ""
    echo "=== Nginx Proxy Logs ==="
    docker logs nginx-coder-proxy --tail 20
}

# Main execution
main() {
    echo "🎯 Nginx-based CORS Solution for Coder-Gerrit Integration"
    echo "========================================================="

    check_docker
    stop_existing_containers
    update_nginx_config
    start_services
    wait_for_services
    test_cors_proxy
    show_summary

    echo "🎉 Nginx proxy setup completed successfully!"
    echo ""
    echo "📊 To view logs:"
    echo "   docker logs coder-server"
    echo "   docker logs nginx-coder-proxy"
    echo ""
    echo "🛑 To stop services:"
    echo "   docker-compose down"
}

# Run main function
main "$@"
