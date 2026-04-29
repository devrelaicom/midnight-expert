#!/usr/bin/env bash
# Reports docker container status for the three Midnight devnet services:
#   midnight-node           -> service "node"
#   midnight-indexer        -> service "indexer"
#   midnight-proof-server   -> service "proof-server"
#
# Output (default): tab-separated lines per service:
#   <service>\t<status>\t<containerName>
# where <status> is one of: running | stopped | not-found
#
# Output with --json:
#   {"services":[{"name":"node","containerName":"...","status":"...","port":N,"url":"..."}, ...],
#    "allRunning":bool}
#
# Exit codes:
#   0 — checks ran successfully (regardless of service state)
#   2 — docker not installed, daemon not running, or other prerequisite failure

set -u

JSON=0
if [ "${1:-}" = "--json" ]; then
  JSON=1
fi

# service-key | containerName | port | url
SERVICES=(
  "node|midnight-node|9944|http://127.0.0.1:9944"
  "indexer|midnight-indexer|8088|http://127.0.0.1:8088/api/v3/graphql"
  "proof-server|midnight-proof-server|6300|http://127.0.0.1:6300"
)

emit_error_json() {
  printf '{"error":"%s","services":[],"allRunning":false}\n' "$1"
}

if ! command -v docker >/dev/null 2>&1; then
  if [ "$JSON" -eq 1 ]; then
    emit_error_json "docker not installed"
  else
    echo "error: docker not installed" >&2
  fi
  exit 2
fi

if ! docker info >/dev/null 2>&1; then
  if [ "$JSON" -eq 1 ]; then
    emit_error_json "docker daemon not running"
  else
    echo "error: docker daemon not running" >&2
  fi
  exit 2
fi

# State map: lines of "<containerName>|<state>"
PS_OUT="$(docker ps -a --filter "name=midnight-" --format '{{.Names}}|{{.State}}' 2>/dev/null || true)"

resolve_status() {
  local target="$1"
  local state=""
  while IFS='|' read -r name s; do
    if [ "$name" = "$target" ]; then
      state="$s"
      break
    fi
  done <<EOF
$PS_OUT
EOF

  if [ -z "$state" ]; then
    printf 'not-found'
  elif [ "$state" = "running" ]; then
    printf 'running'
  else
    printf 'stopped'
  fi
}

ALL_RUNNING=1

if [ "$JSON" -eq 1 ]; then
  printf '{"services":['
  first=1
  for entry in "${SERVICES[@]}"; do
    IFS='|' read -r service container port url <<< "$entry"
    status="$(resolve_status "$container")"
    [ "$status" != "running" ] && ALL_RUNNING=0
    [ "$first" -eq 0 ] && printf ','
    printf '{"name":"%s","containerName":"%s","status":"%s","port":%s,"url":"%s"}' \
      "$service" "$container" "$status" "$port" "$url"
    first=0
  done
  if [ "$ALL_RUNNING" -eq 1 ]; then
    printf '],"allRunning":true}\n'
  else
    printf '],"allRunning":false}\n'
  fi
else
  for entry in "${SERVICES[@]}"; do
    IFS='|' read -r service container _ _ <<< "$entry"
    status="$(resolve_status "$container")"
    [ "$status" != "running" ] && ALL_RUNNING=0
    printf '%s\t%s\t%s\n' "$service" "$status" "$container"
  done
fi

exit 0
