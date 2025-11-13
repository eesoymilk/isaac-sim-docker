# Isaac Sim Docker Launcher

Launches NVIDIA Isaac Sim in headless mode for remote access via WebRTC.

## Prerequisites

- Finish [this guide](https://docs.isaacsim.omniverse.nvidia.com/5.1.0/installation/install_container.html) to install the NVIDIA Container Toolkit and Docker.

## Usage

```bash
chmod +x run-isaac-sim-docker.sh
./run-isaac-sim-docker.sh
```

Detects your public IP, starts Isaac Sim in background, and displays connection details when ready.

## Options

```bash
--version VERSION    Isaac Sim version (default: 5.1.0)
--tailscale          Use Tailscale IP instead of public IP
--help               Show help
```

**Examples:**

```bash
./run-isaac-sim-docker.sh --tailscale
./run-isaac-sim-docker.sh --version 5.0.0 --tailscale
```

## Managing Container

```bash
docker logs -f isaac-sim      # View logs
docker exec -it isaac-sim bash  # Open shell
docker stop isaac-sim         # Stop
```

## Connect

Use **Isaac Sim WebRTC Streaming Client** with the IP and port (49100) shown by the script.

**Resources:** [Docs](https://docs.isaacsim.omniverse.nvidia.com/) | [Container Guide](https://docs.isaacsim.omniverse.nvidia.com/5.1.0/installation/install_container.html)
