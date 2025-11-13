#!/bin/bash

set -e

# Default values
ISAAC_VERSION="5.1.0"
USE_TAILSCALE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            ISAAC_VERSION="$2"
            shift 2
            ;;
        --tailscale)
            USE_TAILSCALE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --version VERSION    Isaac Sim version (default: 5.1.0)"
            echo "  --tailscale          Use Tailscale IP instead of public IP"
            echo "  --help               Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

IMAGE_NAME="nvcr.io/nvidia/isaac-sim:${ISAAC_VERSION}"
BASE_DIR="${HOME}/docker/isaac-sim"
CONTAINER_NAME="isaac-sim"

# Check if container is already running
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo ""
    echo "=========================================="
    echo "WARNING: Container '${CONTAINER_NAME}' already exists"
    echo "=========================================="

    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "Status: RUNNING"
        echo ""
        echo "To connect to the running container:"
        echo "  • Attach to it:    docker attach ${CONTAINER_NAME}"
        echo "                     (Press Ctrl+P then Ctrl+Q to detach)"
        echo "  • Open new shell:  docker exec -it ${CONTAINER_NAME} bash"
        echo "  • View logs:       docker logs -f ${CONTAINER_NAME}"
    else
        echo "Status: STOPPED"
        echo ""
        echo "To restart the stopped container:"
        echo "  docker start ${CONTAINER_NAME}"
    fi

    echo ""
    echo "What would you like to do?"
    echo "1) Stop and restart the container (fresh start)"
    echo "2) Exit and use the existing container"
    echo ""
    read -p "Enter your choice (1 or 2): " choice

    case $choice in
        1)
            echo "Stopping and removing existing container..."
            docker stop ${CONTAINER_NAME} 2>/dev/null || true
            docker rm ${CONTAINER_NAME} 2>/dev/null || true
            echo "Container removed. Starting fresh..."
            ;;
        2)
            echo "Exiting. Use the commands above to interact with the existing container."
            exit 0
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
fi

# Detect IP on host machine before starting container
echo "Detecting IP address..."
if [ "$USE_TAILSCALE" = true ]; then
    if ! command -v tailscale &> /dev/null; then
        echo "Error: tailscale command not found. Please install Tailscale."
        exit 1
    fi
    ENDPOINT_IP=$(tailscale ip -4)
    if [ -z "$ENDPOINT_IP" ]; then
        echo "Error: Could not detect Tailscale IP. Is Tailscale running?"
        exit 1
    fi
    echo "Detected Tailscale IP: $ENDPOINT_IP"
else
    ENDPOINT_IP=$(curl -s ifconfig.me)
    if [ -z "$ENDPOINT_IP" ]; then
        echo "Error: Could not detect public IP"
        exit 1
    fi
    echo "Detected public IP: $ENDPOINT_IP"
fi

echo ""
echo "Starting Isaac Sim container..."

# Start container in detached mode
docker run --name ${CONTAINER_NAME} --entrypoint bash -dit --gpus all \
    -e "ACCEPT_EULA=Y" \
    -e "PRIVACY_CONSENT=Y" \
    --rm \
    --network=host \
    -v ${BASE_DIR}/cache/main:/isaac-sim/.cache:rw \
    -v ${BASE_DIR}/cache/computecache:/isaac-sim/.nv/ComputeCache:rw \
    -v ${BASE_DIR}/logs:/isaac-sim/.nvidia-omniverse/logs:rw \
    -v ${BASE_DIR}/config:/isaac-sim/.nvidia-omniverse/config:rw \
    -v ${BASE_DIR}/data:/isaac-sim/.local/share/ov/data:rw \
    -v ${BASE_DIR}/pkg:/isaac-sim/.local/share/ov/pkg:rw \
    -u 1234:1234 \
    ${IMAGE_NAME} \
    -c "./runheadless.sh --/app/livestream/publicEndpointAddress=${ENDPOINT_IP} --/app/livestream/port=49100"

echo "Container started. Waiting for Isaac Sim to load..."
echo ""

# Follow logs until we see the success message
docker logs -f ${CONTAINER_NAME} 2>&1 | while IFS= read -r line; do
    echo "$line"
    if echo "$line" | grep -q "Isaac Sim Full Streaming App is loaded"; then
        pkill -P $$ docker
        break
    fi
done

# Print connection info
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║       Isaac Sim is Ready!                                 ║"
echo "║                                                            ║"
echo "║  Connect using Isaac Sim WebRTC Streaming Client:         ║"
echo "║                                                            ║"
echo "║  IP Address:  ${ENDPOINT_IP}                                        ║"
echo "║  Port:        49100                                        ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Container is running in the background."
echo ""
echo "Useful commands:"
echo "  • View logs:       docker logs -f ${CONTAINER_NAME}"
echo "  • Open shell:      docker exec -it ${CONTAINER_NAME} bash"
echo "  • Stop container:  docker stop ${CONTAINER_NAME}"
echo ""
