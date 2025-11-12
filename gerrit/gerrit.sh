#!/bin/bash

# Gerrit Docker Management Script
# This script provides commands to build, run, restart, and stop Gerrit containers

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"
IMAGE_NAME="gerritcodereview/gerrit:3.4.1"
CONTAINER_NAME="gerrit"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Download the coder-workspace plugin
download_plugin() {
    local PLUGIN_URL="https://github.com/gerrit-coder/plugins_coder-workspace/releases/download/v1.1.0-gerrit-3.4.1/coder-workspace-v1.1.0-gerrit-3.4.1.jar"
    local PLUGIN_DIR="${SCRIPT_DIR}/plugins"
    local PLUGIN_FILE="${PLUGIN_DIR}/coder-workspace.jar"

    # Create plugins directory if it doesn't exist
    if [ ! -d "${PLUGIN_DIR}" ]; then
        print_info "Creating plugins directory..."
        mkdir -p "${PLUGIN_DIR}"
    fi

    # Check if plugin already exists
    if [ -f "${PLUGIN_FILE}" ]; then
        print_info "Plugin already exists: ${PLUGIN_FILE}"
        return 0
    fi

    # Check for any coder-workspace plugin JAR
    if ls "${PLUGIN_DIR}"/coder-workspace*.jar 1> /dev/null 2>&1; then
        print_info "Found existing coder-workspace plugin in ${PLUGIN_DIR}"
        return 0
    fi

    # Check internet connectivity
    print_info "Checking internet connectivity..."
    if ! curl -s --head --fail https://github.com > /dev/null 2>&1; then
        print_error "Cannot reach github.com. Please check your internet connection."
        exit 1
    fi

    print_info "Downloading coder-workspace plugin..."
    print_info "URL: ${PLUGIN_URL}"
    print_info "Destination: ${PLUGIN_FILE}"

    # Download the plugin
    if command -v curl > /dev/null 2>&1; then
        curl -L -o "${PLUGIN_FILE}" "${PLUGIN_URL}"
    elif command -v wget > /dev/null 2>&1; then
        wget -O "${PLUGIN_FILE}" "${PLUGIN_URL}"
    else
        print_error "Neither curl nor wget is available. Please install one of them to download the plugin."
        exit 1
    fi

    if [ $? -eq 0 ] && [ -f "${PLUGIN_FILE}" ]; then
        print_info "Plugin downloaded successfully!"
        print_info "Plugin file: ${PLUGIN_FILE}"
    else
        print_error "Failed to download plugin"
        exit 1
    fi
}

# Pull the Docker image
build() {
    print_info "Pulling Gerrit Docker image..."
    print_info "Image: ${IMAGE_NAME}"
    cd "${SCRIPT_DIR}"

    if [ ! -f "${COMPOSE_FILE}" ]; then
        print_error "docker-compose.yml not found at ${COMPOSE_FILE}"
        exit 1
    fi

    # Check internet connectivity
    print_info "Checking internet connectivity..."
    if ! curl -s --head --fail https://hub.docker.com > /dev/null 2>&1; then
        print_error "Cannot reach hub.docker.com. Please check your internet connection."
        exit 1
    fi

    print_info "Pulling Docker image..."
    docker pull "${IMAGE_NAME}"

    if [ $? -eq 0 ]; then
        print_info "Gerrit Docker image pulled successfully!"
        print_info "Image: ${IMAGE_NAME}"
    else
        print_error "Failed to pull Gerrit Docker image"
        exit 1
    fi
}

# Run the Gerrit container
run() {
    print_info "Starting Gerrit container..."
    cd "${SCRIPT_DIR}"

    # Check if gerrit.config exists
    if [ ! -f "${SCRIPT_DIR}/etc/gerrit.config" ]; then
        print_error "gerrit.config not found at ${SCRIPT_DIR}/etc/gerrit.config"
        print_info "Please create etc/gerrit.config file before starting the container"
        exit 1
    fi

    # Download plugin if needed
    download_plugin

    # Check if container is already running
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_warn "Container ${CONTAINER_NAME} is already running"
        print_info "Use 'restart' command to restart it, or 'stop' to stop it first"
        return
    fi

    # Start the container
    docker-compose -f "${COMPOSE_FILE}" up -d

    if [ $? -eq 0 ]; then
        print_info "Gerrit container started successfully!"
        print_info "Gerrit is available at:"
        print_info "  HTTP: http://localhost:8080"
        print_info "  SSH:  ssh://localhost:29418"
        print_info ""
        print_info "To view logs: docker logs -f ${CONTAINER_NAME}"
    else
        print_error "Failed to start Gerrit container"
        exit 1
    fi
}

# Restart the Gerrit container
restart() {
    print_info "Restarting Gerrit container..."
    cd "${SCRIPT_DIR}"

    # Check if container exists
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_warn "Container ${CONTAINER_NAME} does not exist. Starting it..."
        run
        return
    fi

    docker-compose -f "${COMPOSE_FILE}" restart

    if [ $? -eq 0 ]; then
        print_info "Gerrit container restarted successfully!"
        print_info "To view logs: docker logs -f ${CONTAINER_NAME}"
    else
        print_error "Failed to restart Gerrit container"
        exit 1
    fi
}

# Stop the Gerrit container
stop() {
    print_info "Stopping Gerrit container..."
    cd "${SCRIPT_DIR}"

    # Check if container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_warn "Container ${CONTAINER_NAME} is not running"
        return
    fi

    docker-compose -f "${COMPOSE_FILE}" down

    if [ $? -eq 0 ]; then
        print_info "Gerrit container stopped successfully!"
    else
        print_error "Failed to stop Gerrit container"
        exit 1
    fi
}

# Show container status
status() {
    print_info "Gerrit container status:"
    echo ""

    if docker ps --format '{{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -q "^${CONTAINER_NAME}"; then
        docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E "NAMES|${CONTAINER_NAME}"
        echo ""
        print_info "Container is running"
    elif docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E "NAMES|${CONTAINER_NAME}"
        echo ""
        print_warn "Container exists but is not running"
    else
        print_warn "Container ${CONTAINER_NAME} does not exist"
    fi
}

# Show logs
logs() {
    local FOLLOW="${2:-}"
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        if [ "${FOLLOW}" = "-f" ] || [ "${FOLLOW}" = "--follow" ] || [ -z "${FOLLOW}" ]; then
            docker logs -f "${CONTAINER_NAME}"
        else
            docker logs "${CONTAINER_NAME}"
        fi
    else
        print_error "Container ${CONTAINER_NAME} is not running"
        exit 1
    fi
}

# Clean up build artifacts and unused Docker resources
clean() {
    print_info "Cleaning up Docker resources..."
    cd "${SCRIPT_DIR}"

    # Stop container if running
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_info "Stopping container..."
        stop
    fi

    # Remove containers if they exist
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_info "Removing container ${CONTAINER_NAME}..."
        docker rm "${CONTAINER_NAME}" 2>/dev/null || true
    fi

    # Remove image if it exists
    if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${IMAGE_NAME}$"; then
        print_info "Removing image ${IMAGE_NAME}..."
        docker rmi "${IMAGE_NAME}" 2>/dev/null || true
    fi

    print_info "Cleanup completed!"
}

# Check if image exists
check_image() {
    if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${IMAGE_NAME}$"; then
        print_info "Image ${IMAGE_NAME} exists"
        docker images "${IMAGE_NAME}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
        return 0
    else
        print_warn "Image ${IMAGE_NAME} does not exist"
        print_info "Run './gerrit.sh build' to build the image"
        return 1
    fi
}

# Show usage information
usage() {
    echo "Usage: $0 {build|run|restart|stop|status|logs|clean|check-image}"
    echo ""
    echo "Commands:"
    echo "  build               - Pull the official Gerrit Docker image"
    echo "                        (gerritcodereview/gerrit:3.4.1)"
    echo "  run                 - Start the Gerrit container"
    echo "  restart             - Restart the Gerrit container"
    echo "  stop                - Stop the Gerrit container"
    echo "  status              - Show the status of the Gerrit container"
    echo "  logs                - Show and follow the Gerrit container logs"
    echo "  clean               - Remove container and image"
    echo "  check-image         - Check if the Docker image exists"
    echo ""
    echo "Examples:"
    echo "  $0 build              # Pull the Docker image"
    echo "  $0 run                # Start Gerrit"
    echo "  $0 logs               # View logs"
    echo ""
    exit 1
}

# Main script logic
case "${1:-}" in
    build)
        build "$@"
        ;;
    run|start)
        run
        ;;
    restart)
        restart
        ;;
    stop)
        stop
        ;;
    status)
        status
        ;;
    logs)
        logs "$@"
        ;;
    clean)
        clean
        ;;
    check-image)
        check_image
        ;;
    *)
        usage
        ;;
esac
