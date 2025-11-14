#!/bin/bash

set -e

# Default values
USE_TAILSCALE=false
USE_DOCKER=false
PORT=49100
GPU_ID=0
ISAAC_SIM_DIR="${HOME}/isaacsim"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --docker)
            USE_DOCKER=true
            shift
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --gpu)
            GPU_ID="$2"
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
            echo "  --docker             Run Isaac Sim in Docker (default: native)"
            echo "  --port PORT          TCP port for streaming (default: 49100)"
            echo "  --gpu GPU_ID         GPU to use for rendering (default: 0)"
            echo "  --tailscale          Use Tailscale IP instead of public IP"
            echo "  --help               Show this help message"
            echo ""
            echo "Native Mode (default):"
            echo "  Runs Isaac Sim from ~/isaacsim/isaac-sim.streaming.sh"
            echo "  Requires Isaac Sim to be installed locally"
            echo ""
            echo "Docker Mode (--docker):"
            echo "  Runs Isaac Sim in a Docker container"
            echo "  Pulls nvidia/isaac-sim image if not present"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Detect IP address
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

# ==============================================================================
# DOCKER MODE
# ==============================================================================
if [ "$USE_DOCKER" = true ]; then
    IMAGE_NAME="nvcr.io/nvidia/isaac-sim:5.1.0"
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
                docker rm -f ${CONTAINER_NAME}
                # Verify container is actually removed
                for i in {1..5}; do
                    if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
                        echo "Container removed. Starting fresh..."
                        break
                    fi
                    if [ $i -eq 5 ]; then
                        echo "Error: Failed to remove container after multiple attempts"
                        exit 1
                    fi
                    sleep 1
                done
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
        -c "./runheadless.sh --/app/livestream/publicEndpointAddress=${ENDPOINT_IP} --/app/livestream/port=${PORT} --/renderer/multiGpu/Enabled=false --/renderer/activeGpu=${GPU_ID}"

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
    echo "║       Isaac Sim is Ready! (Docker Mode)                   ║"
    echo "║                                                            ║"
    echo "║  Connect using Isaac Sim WebRTC Streaming Client:         ║"
    echo "║                                                            ║"
    echo "║  IP Address:  ${ENDPOINT_IP}                                        ║"
    echo "║  Port:        ${PORT}                                        ║"
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

# ==============================================================================
# NATIVE MODE
# ==============================================================================
else
    ISAAC_SCRIPT="${ISAAC_SIM_DIR}/isaac-sim.streaming.sh"

    # Check if Isaac Sim is installed
    if [ ! -d "$ISAAC_SIM_DIR" ]; then
        echo ""
        echo "╔════════════════════════════════════════════════════════════╗"
        echo "║                                                            ║"
        echo "║                    ⚠️  WARNING  ⚠️                          ║"
        echo "║                                                            ║"
        echo "║  Isaac Sim directory not found!                            ║"
        echo "║                                                            ║"
        echo "║  Expected location: ${ISAAC_SIM_DIR}                       ║"
        echo "║                                                            ║"
        echo "║  Please install Isaac Sim or use --docker flag            ║"
        echo "║                                                            ║"
        echo "╚════════════════════════════════════════════════════════════╝"
        echo ""
        exit 1
    fi

    if [ ! -f "$ISAAC_SCRIPT" ]; then
        echo ""
        echo "╔════════════════════════════════════════════════════════════╗"
        echo "║                                                            ║"
        echo "║                    ⚠️  WARNING  ⚠️                          ║"
        echo "║                                                            ║"
        echo "║  Isaac Sim streaming script not found!                    ║"
        echo "║                                                            ║"
        echo "║  Expected: ${ISAAC_SCRIPT}                                 ║"
        echo "║                                                            ║"
        echo "║  Please verify your Isaac Sim installation                ║"
        echo "║  or use --docker flag instead                             ║"
        echo "║                                                            ║"
        echo "╚════════════════════════════════════════════════════════════╝"
        echo ""
        exit 1
    fi

    echo ""
    echo "Starting Isaac Sim (Native Mode)..."
    echo ""

    # Create log file
    LOG_FILE="${ISAAC_SIM_DIR}/isaac-sim-streaming.log"
    PID_FILE="${ISAAC_SIM_DIR}/isaac-sim-streaming.pid"

    # Change to Isaac Sim directory and run the streaming script in background
    cd "$ISAAC_SIM_DIR"
    CUDA_VISIBLE_DEVICES=${GPU_ID} ./isaac-sim.streaming.sh \
        --/app/livestream/publicEndpointAddress="${ENDPOINT_IP}" \
        --/app/livestream/port="${PORT}" \
        --/renderer/multiGpu/Enabled=false \
        --/renderer/activeGpu=${GPU_ID} \
        > "$LOG_FILE" 2>&1 &

    # Save PID
    ISAAC_PID=$!
    echo $ISAAC_PID > "$PID_FILE"

    echo "Process started with PID: $ISAAC_PID"
    echo "Waiting for Isaac Sim to load..."
    echo ""

    # Monitor log file until we see the success message
    tail -f "$LOG_FILE" 2>&1 | while IFS= read -r line; do
        echo "$line"
        if echo "$line" | grep -q "Isaac Sim Full Streaming App is loaded"; then
            pkill -P $$ tail
            break
        fi
    done

    # Check if process is still running
    if ! kill -0 $ISAAC_PID 2>/dev/null; then
        echo ""
        echo "Error: Isaac Sim process terminated unexpectedly"
        echo "Check logs at: $LOG_FILE"
        exit 1
    fi

    # Print connection info
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║       Isaac Sim is Ready! (Native Mode)                   ║"
    echo "║                                                            ║"
    echo "║  Connect using Isaac Sim WebRTC Streaming Client:         ║"
    echo "║                                                            ║"
    echo "║  IP Address:  ${ENDPOINT_IP}                                        ║"
    echo "║  Port:        ${PORT}                                        ║"
    echo "║                                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Process is running in the background (PID: $ISAAC_PID)."
    echo ""
    echo "Useful commands:"
    echo "  • View logs:       tail -f $LOG_FILE"
    echo "  • Stop process:    kill $ISAAC_PID"
    echo "  • Check status:    ps -p $ISAAC_PID"
    echo ""
fi
