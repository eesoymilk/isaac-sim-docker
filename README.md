# Isaac Sim Launcher

Launches NVIDIA Isaac Sim in headless streaming mode for remote access via WebRTC. Supports both Docker and Native modes.

## Prerequisites

**Docker Mode:**
- Finish [this guide](https://docs.isaacsim.omniverse.nvidia.com/5.1.0/installation/install_container.html) to install the NVIDIA Container Toolkit and Docker.

**Native Mode:**
- Install Isaac Sim 5.1.0 to `~/isaacsim`

## Usage

```bash
chmod +x run-isaac-sim-streaming.sh
./run-isaac-sim-streaming.sh
```

Detects your public IP, starts Isaac Sim in background, and displays connection details when ready.

## Options

```bash
--docker             Run Isaac Sim in Docker (default: native)
--port PORT          TCP port for streaming (default: 49100)
--gpu GPU_ID         GPU to use for rendering (default: 0)
--tailscale          Use Tailscale IP instead of public IP
--help               Show help
```

**Examples:**

```bash
# Run in native mode with Tailscale
./run-isaac-sim-streaming.sh --tailscale

# Run in Docker mode on custom port
./run-isaac-sim-streaming.sh --docker --port 8080

# Use specific GPU
./run-isaac-sim-streaming.sh --gpu 1

# Combine options
./run-isaac-sim-streaming.sh --docker --gpu 1 --tailscale --port 8080
```

## Managing Container (Docker Mode)

```bash
docker logs -f isaac-sim         # View logs
docker exec -it isaac-sim bash   # Open shell
docker stop isaac-sim            # Stop
```

## Connect

Use **Isaac Sim WebRTC Streaming Client** with the IP and port shown by the script.

**Resources:** [Docs](https://docs.isaacsim.omniverse.nvidia.com/) | [Container Guide](https://docs.isaacsim.omniverse.nvidia.com/5.1.0/installation/install_container.html)
