#!/bin/bash

# Gerrit Docker Management Script
# This script provides commands to build, run, restart, and stop Gerrit containers

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"
IMAGE_NAME="gerrit:3.4.1"
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

# Build the Docker image
build() {
    # Check if --no-cache flag is provided in any argument
    local NO_CACHE=""
    for arg in "$@"; do
        if [ "${arg}" = "--no-cache" ] || [ "${arg}" = "no-cache" ]; then
            NO_CACHE="--no-cache"
            break
        fi
    done

    print_info "Building Gerrit Docker image..."
    print_info "This will download pre-built Gerrit v3.4.1 WAR and build the coder-workspace plugin"
    print_warn "This process may take 5-15 minutes depending on your system and network speed"
    cd "${SCRIPT_DIR}"

    if [ ! -f "${COMPOSE_FILE}" ]; then
        print_error "docker-compose.yml not found at ${COMPOSE_FILE}"
        exit 1
    fi

    if [ ! -f "${SCRIPT_DIR}/Dockerfile" ]; then
        print_error "Dockerfile not found at ${SCRIPT_DIR}/Dockerfile"
        exit 1
    fi

    # Check internet connectivity
    print_info "Checking internet connectivity..."
    if ! curl -s --head --fail https://gerrit-releases.storage.googleapis.com > /dev/null 2>&1; then
        print_error "Cannot reach gerrit-releases.storage.googleapis.com. Please check your internet connection."
        exit 1
    fi
    if ! curl -s --head --fail https://github.com > /dev/null 2>&1; then
        print_error "Cannot reach github.com. Please check your internet connection."
        exit 1
    fi

    local BUILD_CMD="docker-compose -f ${COMPOSE_FILE} build"
    if [ -n "${NO_CACHE}" ]; then
        BUILD_CMD="${BUILD_CMD} ${NO_CACHE}"
        print_info "Building without cache..."
    else
        print_info "Building with cache (use 'build --no-cache' for a clean build)..."
    fi

    ${BUILD_CMD}

    if [ $? -eq 0 ]; then
        print_info "Gerrit Docker image built successfully!"
        print_info "Image: ${IMAGE_NAME}"
    else
        print_error "Failed to build Gerrit Docker image"
        exit 1
    fi
}

# Run the Gerrit container
run() {
    print_info "Starting Gerrit container..."
    cd "${SCRIPT_DIR}"

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

    # Remove container if it exists
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_info "Removing container..."
        docker rm "${CONTAINER_NAME}" 2>/dev/null || true
    fi

    # Remove image if it exists
    if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${IMAGE_NAME}$"; then
        print_info "Removing image ${IMAGE_NAME}..."
        docker rmi "${IMAGE_NAME}" 2>/dev/null || true
    fi

    # Clean up build cache (optional)
    print_info "Cleaning up Docker build cache..."
    docker builder prune -f

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
    echo "  build [--no-cache]  - Build the Gerrit Docker image"
    echo "                        (downloads pre-built Gerrit v3.4.1 WAR and builds coder-workspace plugin)"
    echo "                        Use --no-cache for a clean build"
    echo "  run                 - Start the Gerrit container"
    echo "  restart             - Restart the Gerrit container"
    echo "  stop                - Stop the Gerrit container"
    echo "  status              - Show the status of the Gerrit container"
    echo "  logs                - Show and follow the Gerrit container logs"
    echo "  clean               - Remove container, image, and clean build cache"
    echo "  check-image         - Check if the Docker image exists"
    echo ""
    echo "Examples:"
    echo "  $0 build              # Build with cache"
    echo "  $0 build --no-cache  # Build without cache (clean build)"
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
