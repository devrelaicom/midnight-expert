# Proof Server Issues

Diagnose and resolve Docker and proof server problems for the Midnight proof server.

## Missing ZK Parameters Error

**Error:** `public parameters for k=16 not found in cache` (or similar ZK parameter messages)

**Cause:** The proof server requires pre-computed zero-knowledge parameters that are downloaded on first run and cached locally. This error means the parameters haven't been downloaded or the cache is corrupted.

**Fix:**
1. Check Docker volume for cached parameters:
   ```bash
   docker volume ls | grep midnight
   ```
2. If the volume exists but is corrupt, remove and recreate:
   ```bash
   docker volume rm midnight-proof-server-params
   ```
3. Restart the proof server - it will re-download the parameters on startup. This download can take several minutes depending on network speed.
4. Ensure the container has network access during startup to download parameters.

## Port 6300 Conflicts

**Error:** Port 6300 already in use, bind error, or address already in use.

**Cause:** Another process (possibly a previous proof server instance) is using port 6300.

**Fix:**
1. Find what's using port 6300:
   ```bash
   lsof -i :6300
   ```
   On Linux if `lsof` is not available:
   ```bash
   ss -tlnp | grep 6300
   ```
2. Stop the conflicting process, or stop the old container:
   ```bash
   docker ps | grep proof-server
   docker stop <container-id>
   ```
3. If a stopped container is still holding the port binding, remove it:
   ```bash
   docker rm <container-id>
   ```
4. Alternatively, map to a different host port:
   ```bash
   docker run -p 6301:6300 ...
   ```
   Then update the application configuration to use port 6301.

## Docker Resource Constraints

**Symptoms:** Proof server crashes, gets OOM-killed, or runs extremely slowly.

**Cause:** The proof server requires significant resources for zero-knowledge proof generation. Minimum 4 GB RAM is recommended.

**Fix:**
1. Check Docker resource limits:
   - **Docker Desktop (macOS/Windows):** Settings > Resources > Memory. Increase to at least 4 GB, preferably 8 GB.
   - **Linux:** Check cgroup limits if applicable. Docker on Linux uses host resources directly unless limited.
2. Check if the container was OOM-killed:
   ```bash
   docker inspect <container-id> --format='{{.State.OOMKilled}}'
   ```
3. Monitor resource usage during proof generation:
   ```bash
   docker stats <container-id>
   ```
4. If running other Docker containers alongside, ensure total resource allocation is sufficient.

## Docker Daemon Not Running

**Error:** Cannot connect to the Docker daemon, docker: command not found, permission denied.

**Fix by platform:**

### macOS
- Ensure Docker Desktop is running (check menu bar icon)
- If just installed, restart may be required
- Verify: `docker info`

### Linux
- Start the daemon:
  ```bash
  sudo systemctl start docker
  ```
- Enable on boot:
  ```bash
  sudo systemctl enable docker
  ```
- **Permission denied** without sudo - add user to the docker group:
  ```bash
  sudo usermod -aG docker $USER
  ```
  Then **log out and back in** (or `newgrp docker`) for the group change to take effect.

### Windows
- Ensure Docker Desktop is running with WSL 2 backend enabled
- Check WSL integration is enabled for the correct distro in Docker Desktop settings
- Verify: `wsl docker info`

## Health Check Failures

If the proof server container is running but not responding:

1. Check container status:
   ```bash
   docker ps -a | grep proof-server
   ```
2. Check logs for errors:
   ```bash
   docker logs <container-id> --tail 50
   ```
3. Test health endpoints:
   ```bash
   curl -s http://localhost:6300/health
   curl -s http://localhost:6300/version
   curl -s http://localhost:6300/ready
   ```
4. If `/health` returns OK but `/ready` does not, the server is still loading ZK parameters. Wait and retry.

## If Issues Persist

1. Search for proof server issues: `gh search issues "proof server org:midnightntwrk" --state=open --limit=20 --sort=updated --json "title,url,updatedAt,commentsCount"`
2. Also search for Docker-specific issues: `gh search issues "docker org:midnightntwrk" --state=open --limit=20 --sort=updated --json "title,url,updatedAt,commentsCount"`
3. Check release notes for the proof server version in use via `references/checking-release-notes.md`
