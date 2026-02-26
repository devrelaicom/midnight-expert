---
description: Start the Midnight proof server in Docker, verify it is healthy, and run it in the background
allowed-tools: Bash, Read, AskUserQuestion
argument-hint: [--restart | --stop | --logs | --rm | --version <tag>]
---

Start, restart, or manage the Midnight proof server Docker container.

## Step 1: Parse Intent from Arguments

Analyze `$ARGUMENTS` to determine the action and version:

**Action:**

- **Stop** if arguments contain "stop", "kill", "down", or `--stop`
  - Jump to Step 6 (Stop)
- **Logs** if arguments contain "logs", "status", or `--logs`
  - Jump to Step 7 (Logs)
- **Force recreate** if arguments contain `--rm`
  - Proceed from Step 2 with forced removal and recreation of the container
- **Restart** if arguments contain "restart", "reset", or `--restart`
  - Proceed from Step 2 with `docker restart` for existing containers
- **Start** (default): No arguments or "start", "run", "up"
  - Proceed from Step 2

**Version:**

Extract the image tag from `--version <tag>` if present. Store it for use in Step 3. If `--version` is not provided, Step 3 will resolve the latest stable version.

## Step 2: Check Prerequisites

### Docker installed and running

```bash
docker --version 2>&1
docker info >/dev/null 2>&1 && echo "Docker daemon is running" || echo "Docker daemon is NOT running"
```

If Docker is not installed, inform the user to install Docker Desktop from [https://www.docker.com/products/docker-desktop/](https://www.docker.com/products/docker-desktop/) and stop.

If Docker is installed but the daemon is not running, inform the user to start Docker Desktop and wait for it to be ready, then stop.

## Step 3: Resolve Image Version

Determine which image tag to use for creating new containers. Skip this step if the action is **stop** or **logs**.

**If `--version <tag>` was provided**: Use the specified tag exactly (e.g., `8.0.0-rc.4`, `latest`, `7.0.0`).

**If no version was specified**: Fetch the latest stable version from Docker Hub:

```bash
STABLE_VERSION=$(curl -s "https://registry.hub.docker.com/v2/repositories/midnightntwrk/proof-server/tags/?page_size=100&ordering=last_updated" \
  | grep -o '"name": *"[^"]*"' \
  | sed 's/"name": *"//;s/"$//' \
  | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
  | sort -t. -k1,1n -k2,2n -k3,3n \
  | tail -1)
echo "${STABLE_VERSION:-not found}"
```

This filters to tags matching strict semver (`X.Y.Z` only — no `-rc`, `-alpha`, `-beta`, `-performance`, or architecture suffixes), sorts numerically, and selects the highest version.

- If a stable version is found: use it as the image tag.
- If no stable version is found (empty result): fall back to `latest` and warn the user that no stable release was found.
- If the curl request fails: fall back to `latest` and warn that the version list could not be fetched.

Store the resolved tag — referred to as `$IMAGE_TAG` in subsequent steps.

## Step 4: Handle Existing Container

Check for an existing proof server container (running or stopped):

```bash
docker ps -a --filter "name=midnight-proof-server" --format "{{.Names}} {{.Status}} {{.Image}}" 2>&1
```

**If `--rm` (force recreate):**
- Remove the existing container regardless of state:

```bash
docker rm -f midnight-proof-server 2>/dev/null
```

- Proceed to Step 5 (Start and Verify) to create a fresh container with `$IMAGE_TAG`

**If a running container exists:**
- If **restart**: run `docker restart midnight-proof-server`, then verify (Step 5 — verification only)
- If **start** (default): inform the user the proof server is already running, verify it is responding (Step 5 — verification only), do not start a second container

**If a stopped container exists:**
- Start the existing container:

```bash
docker start midnight-proof-server
```

- Proceed to Step 5 (verification only)

**If no container exists:**
- Proceed to Step 5 (Start and Verify) to create a new container

**Version mismatch**: When an existing container is found (running or stopped) and the user specified `--version`, check whether the container's image tag matches the requested version. If it does not match, inform the user of the mismatch and suggest using `--rm --version <tag>` to recreate the container with the desired version.

## Step 5: Start and Verify

If creating a new container (no existing container, or `--rm`), start the proof server in detached mode using the resolved `$IMAGE_TAG`:

```bash
docker run -d --name midnight-proof-server -p 6300:6300 midnightntwrk/proof-server:$IMAGE_TAG -- midnight-proof-server -v
```

Report which image tag is being used (e.g., "Starting proof server with image `midnightntwrk/proof-server:7.0.2`").

Wait briefly for the server to initialize, then verify:

```bash
sleep 3
docker ps --filter "name=midnight-proof-server" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>&1
```

Check that the server is healthy and responding on port 6300:

```bash
curl -sf --max-time 10 http://localhost:6300/health 2>&1 || echo "Not yet responding"
```

If the server is not responding after the initial check, wait a few more seconds and retry once:

```bash
sleep 5
curl -sf --max-time 10 http://localhost:6300/health 2>&1 || echo "Proof server failed to start - check logs with: docker logs midnight-proof-server"
```

If the server still fails to respond, show the container logs to help diagnose:

```bash
docker logs --tail 30 midnight-proof-server 2>&1
```

If the server is healthy, also fetch the version and readiness status:

```bash
curl -sf --max-time 5 http://localhost:6300/version 2>&1
curl -sf --max-time 5 http://localhost:6300/ready 2>&1
```

Report the result:
- **Success**: Proof server is running in the background on http://localhost:6300 — include the image tag, server version, and readiness info (job capacity) in the report
- **Failure**: Show logs and suggest the user check Docker resource allocation

## Step 6: Stop

**If `--rm` is also present (e.g. `--stop --rm`):**
- Stop and remove the container:

```bash
docker rm -f midnight-proof-server 2>&1
```

- Confirm the server has been stopped and removed.

**Otherwise (default `--stop`):**
- Stop the container without removing it:

```bash
docker stop midnight-proof-server 2>&1
```

- Confirm the server has been stopped. Note that the container is preserved and can be started again quickly.

## Step 7: Logs

Show the current status, API health info, and recent logs:

```bash
docker ps --filter "name=midnight-proof-server" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>&1
curl -sf --max-time 5 http://localhost:6300/health 2>&1 || echo "Health endpoint not responding"
curl -sf --max-time 5 http://localhost:6300/version 2>&1 || echo "Version endpoint not responding"
curl -sf --max-time 5 http://localhost:6300/ready 2>&1 || echo "Ready endpoint not responding"
docker logs --tail 50 midnight-proof-server 2>&1
```

If no container exists, inform the user the proof server is not running.
