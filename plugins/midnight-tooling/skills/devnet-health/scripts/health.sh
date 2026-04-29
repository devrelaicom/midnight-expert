#!/usr/bin/env bash
# HTTP health probes for the three Midnight devnet services:
#   node          -> GET http://127.0.0.1:9944/health
#   indexer       -> GET http://127.0.0.1:8088/ready
#   proof-server  -> GET http://127.0.0.1:6300/version
#
# A service is "healthy" when it returns an HTTP 2xx within the 5s timeout.
#
# Output (default): tab-separated lines per service:
#   <service>\t<healthy|unhealthy>\t<response_ms>\t<http_code>
#
# Output with --json:
#   {"node":{"healthy":bool,"responseTimeMs":N,"httpCode":N},
#    "indexer":{...},
#    "proofServer":{...},
#    "allHealthy":bool}
#
# Exit codes:
#   0 — checks ran successfully (regardless of health)
#   2 — curl not installed

set -u

JSON=0
if [ "${1:-}" = "--json" ]; then
  JSON=1
fi

TIMEOUT_SECS=5

# service-key | json-key | url
SERVICES=(
  "node|node|http://127.0.0.1:9944/health"
  "indexer|indexer|http://127.0.0.1:8088/ready"
  "proof-server|proofServer|http://127.0.0.1:6300/version"
)

if ! command -v curl >/dev/null 2>&1; then
  if [ "$JSON" -eq 1 ]; then
    printf '{"error":"curl not installed","allHealthy":false}\n'
  else
    echo "error: curl not installed" >&2
  fi
  exit 2
fi

probe() {
  # Echoes "<healthy|unhealthy>|<ms>|<http_code>" for the given URL.
  local url="$1"
  local out code time_s ms healthy
  out="$(curl -s -o /dev/null -w '%{http_code} %{time_total}' \
    --max-time "$TIMEOUT_SECS" "$url" 2>/dev/null)" || out=""
  if [ -z "$out" ]; then
    out="000 ${TIMEOUT_SECS}"
  fi
  code="$(printf '%s\n' "$out" | awk '{print $1}')"
  time_s="$(printf '%s\n' "$out" | awk '{print $2}')"
  ms="$(printf '%s\n' "$time_s" | awk '{printf "%d", ($1 * 1000) + 0.5}')"
  if [ "$code" -ge 200 ] 2>/dev/null && [ "$code" -lt 300 ] 2>/dev/null; then
    healthy="healthy"
  else
    healthy="unhealthy"
  fi
  printf '%s|%s|%s\n' "$healthy" "$ms" "$code"
}

ALL_HEALTHY=1

if [ "$JSON" -eq 1 ]; then
  printf '{'
  first=1
  for entry in "${SERVICES[@]}"; do
    IFS='|' read -r service json_key url <<< "$entry"
    res="$(probe "$url")"
    status="$(printf '%s' "$res" | awk -F'|' '{print $1}')"
    ms="$(printf '%s' "$res" | awk -F'|' '{print $2}')"
    code="$(printf '%s' "$res" | awk -F'|' '{print $3}')"
    if [ "$status" = "healthy" ]; then
      healthy_json="true"
    else
      healthy_json="false"
      ALL_HEALTHY=0
    fi
    [ "$first" -eq 0 ] && printf ','
    printf '"%s":{"healthy":%s,"responseTimeMs":%s,"httpCode":%s}' \
      "$json_key" "$healthy_json" "$ms" "$code"
    first=0
  done
  if [ "$ALL_HEALTHY" -eq 1 ]; then
    printf ',"allHealthy":true}\n'
  else
    printf ',"allHealthy":false}\n'
  fi
else
  for entry in "${SERVICES[@]}"; do
    IFS='|' read -r service _ url <<< "$entry"
    res="$(probe "$url")"
    status="$(printf '%s' "$res" | awk -F'|' '{print $1}')"
    ms="$(printf '%s' "$res" | awk -F'|' '{print $2}')"
    code="$(printf '%s' "$res" | awk -F'|' '{print $3}')"
    [ "$status" != "healthy" ] && ALL_HEALTHY=0
    printf '%s\t%s\t%s\t%s\n' "$service" "$status" "$ms" "$code"
  done
fi

exit 0
