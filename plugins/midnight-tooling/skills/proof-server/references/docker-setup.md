# Docker Setup for Midnight Proof Server

## Installing Docker Desktop

Download Docker Desktop for the appropriate platform:

- **All platforms**: [https://www.docker.com/products/docker-desktop/](https://www.docker.com/products/docker-desktop/)

### macOS

Docker Desktop for Mac is available for both Intel and Apple Silicon. After installation, Docker Desktop appears in the Applications folder. Launch it and wait for the whale icon in the menu bar to show "Docker Desktop is running."

**Apple Silicon note:** Docker Desktop handles multi-architecture images automatically. If you encounter architecture-related issues with the proof server image, force the platform explicitly:

```bash
docker run -d --platform linux/amd64 --name midnight-proof-server -p 6300:6300 midnightntwrk/proof-server:<tag> -- midnight-proof-server -v
```

Verify installation:

```bash
docker --version
docker info
```

### Linux

On Linux, Docker can be installed as Docker Desktop (GUI) or Docker Engine (CLI only). Either works for the proof server. If using Docker Engine, ensure the user's account is in the `docker` group to avoid needing `sudo`:

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

If `docker` is not recognized in PowerShell or Command Prompt, ensure Docker Desktop is running and the CLI is on your PATH. Docker Desktop typically adds itself to PATH during installation — restart the terminal if needed.

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

The proof server generates zero-knowledge proofs, which can be memory-intensive. Ensure Docker Desktop has adequate resources allocated:

- **Recommended minimum**: 4 GB RAM allocated to Docker
- **Recommended CPU**: At least 2 cores

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

### Port 6300 in use

If port 6300 is already occupied by another process:

```bash
# Find what's using port 6300
lsof -i :6300
```

Either stop the conflicting process or map the proof server to a different host port:

```bash
docker run -d --name midnight-proof-server -p 6301:6300 midnightntwrk/proof-server:<tag> -- midnight-proof-server -v
```

Note: When using an alternate port, update the DApp configuration to point to the new port.

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
