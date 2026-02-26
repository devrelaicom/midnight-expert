#!/usr/bin/env bash
set -u

emit() {
  local name="$1"
  local status="$2"
  local detail="$3"
  detail="$(printf '%s' "$detail" | tr '\n' ';' | sed 's/  */ /g; s/; */; /g; s/; $//')"
  printf '%s | %s | %s\n' "$name" "$status" "$detail"
}

have_docker=0
if docker_version="$(docker --version 2>&1)"; then
  have_docker=1
  emit "Docker installed" "pass" "installed"
  emit "Docker version" "info" "$docker_version"
else
  emit "Docker installed" "critical" "not installed"
fi

if [ "$have_docker" -eq 1 ]; then
  if docker info >/dev/null 2>&1; then
    emit "Docker daemon" "pass" "running"
    docker_running=1
  else
    emit "Docker daemon" "critical" "not running"
    docker_running=0
  fi
else
  docker_running=0
fi

if [ "$docker_running" -eq 1 ]; then
  container_line="$(docker ps --filter "name=midnight-proof-server" --format "{{.Names}} {{.Status}}" 2>&1)" || container_line=""
  if [ -n "$container_line" ]; then
    emit "Proof server container" "pass" "$container_line"
  else
    stopped_line="$(docker ps -a --filter "name=midnight-proof-server" --format "{{.Names}} {{.Status}}" 2>&1)" || stopped_line=""
    if [ -n "$stopped_line" ]; then
      emit "Proof server container" "warn" "stopped"
    else
      emit "Proof server container" "warn" "not found"
    fi
  fi

  health_resp="$(curl -sf --max-time 5 http://localhost:6300/health 2>&1)" || health_resp=""
  health_ok=0
  if [ -n "$health_resp" ] && printf '%s' "$health_resp" | grep -qi '"status" *: *"ok"'; then
    emit "Proof server health" "pass" "healthy"
    health_ok=1
  else
    emit "Proof server health" "warn" "not responding on port 6300"
  fi

  if [ "$health_ok" -eq 1 ]; then
    version_resp="$(curl -sf --max-time 5 http://localhost:6300/version 2>&1)" || version_resp=""
    if [ -n "$version_resp" ]; then
      emit "Proof server version" "info" "$version_resp"
    else
      emit "Proof server version" "warn" "could not retrieve version"
    fi

    ready_resp="$(curl -sf --max-time 5 http://localhost:6300/ready 2>&1)" || ready_resp=""
    if [ -n "$ready_resp" ] && printf '%s' "$ready_resp" | grep -qi '"status" *: *"ok"'; then
      capacity="$(printf '%s' "$ready_resp" | grep -o '"jobCapacity"[[:space:]]*:[[:space:]]*[0-9]*' | head -1 | sed 's/[^0-9]*//g')"
      capacity="${capacity:-?}"
      emit "Proof server ready" "pass" "ready (capacity: ${capacity})"
    elif [ -n "$ready_resp" ] && printf '%s' "$ready_resp" | grep -qi '"status" *: *"busy"'; then
      processing="$(printf '%s' "$ready_resp" | grep -o '"jobsProcessing"[[:space:]]*:[[:space:]]*[0-9]*' | head -1 | sed 's/[^0-9]*//g')"
      pending="$(printf '%s' "$ready_resp" | grep -o '"jobsPending"[[:space:]]*:[[:space:]]*[0-9]*' | head -1 | sed 's/[^0-9]*//g')"
      capacity="$(printf '%s' "$ready_resp" | grep -o '"jobCapacity"[[:space:]]*:[[:space:]]*[0-9]*' | head -1 | sed 's/[^0-9]*//g')"
      processing="${processing:-?}"
      pending="${pending:-?}"
      capacity="${capacity:-?}"
      emit "Proof server ready" "warn" "busy (processing: ${processing}, pending: ${pending}, capacity: ${capacity})"
    else
      emit "Proof server ready" "warn" "readiness endpoint not responding"
    fi
  fi
fi
