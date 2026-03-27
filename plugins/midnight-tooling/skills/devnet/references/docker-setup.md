# Docker Setup for Midnight Development Network

This guide covers Docker installation and configuration for running the Midnight local development network (devnet). The devnet runs 3 services as Docker containers: a blockchain node, an indexer, and a proof server. This guide applies to both full devnet usage and standalone proof-server usage.

## Installing Docker Desktop

Download Docker Desktop for the appropriate platform:

- **All platforms**: [https://www.docker.com/products/docker-desktop/](https://www.docker.com/products/docker-desktop/)

### macOS

Docker Desktop for Mac is available for both Intel and Apple Silicon. After installation, Docker Desktop appears in the Applications folder. Launch it and wait for the whale icon in the menu bar to show "Docker Desktop is running."

**Apple Silicon note:** Docker Desktop handles multi-architecture images automatically. If you encounter architecture-related issues with any of the devnet container images, you may need to force the platform explicitly when pulling images. The devnet Docker Compose file handles multi-architecture images automatically. If you encounter issues with a specific image, add `platform: linux/amd64` to the service definition in your `devnet.yml`.

Verify installation:

```bash
docker --version
docker info
```

### Linux

On Linux, Docker can be installed as Docker Desktop (GUI) or Docker Engine (CLI only). Either works for the devnet. If using Docker Engine, ensure the user's account is in the `docker` group to avoid needing `sudo`:

```bash
sudo usermod -aG docker $USER
```

Log out and back in for the group change to take effect.

### Windows

Docker Desktop for Windows requires WSL 2 or Hyper-V. After installation, ensure Docker is set to use Linux containers (the default).

Verify installation:

```bash
docker --version
docker info
```

If `docker` is not recognized in PowerShell or Command Prompt, ensure Docker Desktop is running and the CLI is on your PATH. Docker Desktop typically adds itself to PATH during installation -- restart the terminal if needed.

**WSL 2 troubleshooting:**

If Docker Desktop fails to start with WSL 2 errors:

1. Ensure WSL 2 is installed: `wsl --install` (from an elevated PowerShell)
2. Set WSL default version: `wsl --set-default-version 2`
3. Restart Docker Desktop

## Verifying Docker is Ready

Run these checks in sequence:

```bash
# 1. Docker CLI is installed
docker --version

# 2. Docker daemon is running and responsive
docker info

# 3. Docker can pull and run images
docker run --rm hello-world
```

If step 2 fails with "Cannot connect to the Docker daemon", Docker Desktop needs to be started. On macOS, launch it from Applications. On Linux, start the service:

```bash
sudo systemctl start docker
```

## Resource Considerations

The devnet runs 3 services simultaneously (blockchain node, indexer, and proof server), with the proof server being the most memory-intensive due to zero-knowledge proof generation. Ensure Docker Desktop has adequate resources allocated:

- **Recommended minimum**: 4 GB RAM allocated to Docker
- **Recommended CPU**: At least 2 cores

These minimums apply whether you are running the full devnet or just the proof server standalone.

To adjust resources in Docker Desktop:
1. Open Docker Desktop settings
2. Navigate to Resources
3. Adjust memory and CPU limits
4. Apply and restart

## Troubleshooting Docker Daemon

### macOS: Docker daemon not starting

If Docker Desktop shows "Docker Desktop starting..." indefinitely:

1. Quit Docker Desktop completely
2. Remove the Docker state: `rm -rf ~/Library/Containers/com.docker.docker`
3. Relaunch Docker Desktop

**Warning**: This removes all containers and images. Only do this as a last resort.

### Linux: Permission denied

If `docker` commands fail with "permission denied":

```bash
# Check if user is in docker group
groups | grep docker

# If not, add and re-login
sudo usermod -aG docker $USER
# Then log out and back in
```

### Port conflicts

The devnet uses three ports. If any are already occupied by another process, the corresponding service will fail to start.

| Port | Service | Find conflict |
|------|---------|--------------|
| 9944 | Node | `lsof -i :9944` |
| 8088 | Indexer | `lsof -i :8088` |
| 6300 | Proof server | `lsof -i :6300` |

To resolve a port conflict, stop the conflicting process before starting the devnet. The default port mappings are configured in `devnet.yml`. While you can change the host-side port (e.g., `'9945:9944'`), the services communicate internally via Docker DNS on their default ports, so only the host port should be changed.

If you are running the proof server standalone (outside the devnet), and port 6300 is in use, you can map to a different host port:

```bash
docker run -d --name midnight-proof-server -p 6301:6300 midnightntwrk/proof-server:<tag> -- midnight-proof-server -v
```

Note: When using an alternate port for standalone usage, update the DApp configuration to point to the new port.

### Multiple Docker installations (docker context)

Systems with both Docker Desktop and Docker Engine may route commands to the wrong daemon. Check and switch the active context:

```bash
# List available contexts
docker context ls

# Switch to Docker Desktop
docker context use desktop-linux

# Switch to Docker Engine
docker context use default
```

If `docker info` succeeds but containers behave unexpectedly, verify you are targeting the intended Docker daemon with `docker context ls`.
