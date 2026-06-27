#!/usr/bin/env bash
set -euo pipefail

# Starts the local SmartKit AI stack for a real Android phone APK:
#   phone APK -> Supabase Edge Functions -> Cloudflare Tunnel -> this laptop -> Ollama
#
# Keep this script running while the phone should use AI.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${SMARTKIT_ENV_FILE:-${ROOT_DIR}/.env}"
RUNTIME_DIR="${ROOT_DIR}/.dart_tool/smartkit_phone_demo"
LOG_DIR="${RUNTIME_DIR}/logs"
TOKEN_FILE="${RUNTIME_DIR}/ollama_proxy_token"

mkdir -p "$LOG_DIR"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

PROJECT_REF="${SUPABASE_PROJECT_REF:-}"
if [[ -z "$PROJECT_REF" && "${SUPABASE_URL:-}" =~ ^https://([^.]+)\.supabase\.co/?$ ]]; then
  PROJECT_REF="${BASH_REMATCH[1]}"
fi

MODEL="${OLLAMA_MODEL:-qwen3:latest}"
OLLAMA_URL="${SMARTKIT_LOCAL_OLLAMA_URL:-http://127.0.0.1:11434}"
PROXY_PORT="${SMARTKIT_PROXY_PORT:-11500}"
PROXY_URL="http://127.0.0.1:${PROXY_PORT}"
DEPLOY_FUNCTIONS="${SMARTKIT_DEPLOY_FUNCTIONS:-yes}"
CLOUDFLARED_PROTOCOL="${SMARTKIT_CLOUDFLARED_PROTOCOL:-http2}"

if [[ -n "${OLLAMA_PROXY_TOKEN:-}" ]]; then
  PROXY_TOKEN="$OLLAMA_PROXY_TOKEN"
elif [[ -n "${OLLAMA_API_KEY:-}" ]]; then
  PROXY_TOKEN="$OLLAMA_API_KEY"
elif [[ -f "$TOKEN_FILE" ]]; then
  PROXY_TOKEN="$(cat "$TOKEN_FILE")"
else
  PROXY_TOKEN="$(openssl rand -hex 32)"
  umask 077
  printf '%s' "$PROXY_TOKEN" > "$TOKEN_FILE"
fi

OLLAMA_PID=""
PROXY_PID=""
TUNNEL_PID=""
CLEANED_UP="no"

usage() {
  cat <<EOF
Usage:
  SUPABASE_ACCESS_TOKEN=YOUR_TOKEN $0

Required for phone APK:
  SUPABASE_ACCESS_TOKEN  Supabase account access token. Create it in:
                         Supabase Dashboard -> Account -> Access Tokens

Optional:
  OLLAMA_MODEL                 Default: ${MODEL}
  SUPABASE_PROJECT_REF          Default: parsed from .env SUPABASE_URL
  SMARTKIT_DEPLOY_FUNCTIONS=no  Only update secrets, skip functions deploy
  SMARTKIT_SKIP_SUPABASE_UPDATE=yes
                                Start local AI/tunnel only, do not change Supabase
  SMARTKIT_SKIP_MODEL_PULL=yes  Do not run 'ollama pull'
  SMARTKIT_CLOUDFLARED_PROTOCOL Default: ${CLOUDFLARED_PROTOCOL}

What it starts:
  - Ollama on ${OLLAMA_URL}
  - SmartKit proxy on ${PROXY_URL}
  - Cloudflare quick tunnel to the proxy
  - Supabase secrets:
      OLLAMA_BASE_URL=<trycloudflare URL>
      OLLAMA_MODEL=${MODEL}
      OLLAMA_API_KEY=<proxy token>
EOF
}

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

cleanup() {
  if [[ "$CLEANED_UP" == "yes" ]]; then
    return
  fi
  CLEANED_UP="yes"
  echo
  echo "Stopping SmartKit local AI demo processes..."
  if [[ -n "$TUNNEL_PID" ]] && kill -0 "$TUNNEL_PID" >/dev/null 2>&1; then
    kill "$TUNNEL_PID" >/dev/null 2>&1 || true
  fi
  if [[ -n "$PROXY_PID" ]] && kill -0 "$PROXY_PID" >/dev/null 2>&1; then
    kill "$PROXY_PID" >/dev/null 2>&1 || true
  fi
  if [[ -n "$OLLAMA_PID" ]] && kill -0 "$OLLAMA_PID" >/dev/null 2>&1; then
    kill "$OLLAMA_PID" >/dev/null 2>&1 || true
  fi
}

require_command() {
  local command_name="$1"
  local install_hint="$2"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing command: $command_name"
    echo "$install_hint"
    exit 1
  fi
}

wait_for_http() {
  local url="$1"
  local name="$2"
  local timeout_seconds="${3:-60}"
  local started_at
  started_at="$(date +%s)"

  local last_notice=0

  until curl -fsS "$url" >/dev/null 2>&1; do
    if (( "$(date +%s)" - started_at > timeout_seconds )); then
      echo "$name did not become ready: $url"
      return 1
    fi
    if (( "$(date +%s)" - last_notice >= 5 )); then
      log "Waiting for ${name}: ${url}"
      last_notice="$(date +%s)"
    fi
    sleep 1
  done
}

wait_for_public_tunnel() {
  local url="$1"
  local timeout_seconds="${2:-180}"
  local started_at
  started_at="$(date +%s)"

  while true; do
    if curl -fsS --connect-timeout 10 "${url}/health" >/dev/null 2>&1; then
      return 0
    fi

    if ! kill -0 "$TUNNEL_PID" >/dev/null 2>&1; then
      echo "cloudflared stopped unexpectedly. Log:"
      tail -100 "${LOG_DIR}/cloudflared.log" || true
      return 1
    fi

    if (( "$(date +%s)" - started_at > timeout_seconds )); then
      echo "Cloudflare tunnel URL did not become reachable within ${timeout_seconds}s:"
      echo "  ${url}"
      echo
      echo "Last cloudflared log lines:"
      tail -100 "${LOG_DIR}/cloudflared.log" || true
      return 1
    fi

    log "Waiting for Cloudflare tunnel DNS/health..."
    sleep 5
  done
}

kill_old_pid_file_process() {
  local pid_file="$1"
  if [[ -f "$pid_file" ]]; then
    local old_pid
    old_pid="$(cat "$pid_file" 2>/dev/null || true)"
    if [[ -n "$old_pid" ]] && kill -0 "$old_pid" >/dev/null 2>&1; then
      kill "$old_pid" >/dev/null 2>&1 || true
      sleep 1
    fi
    rm -f "$pid_file"
  fi
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ -z "$PROJECT_REF" ]]; then
  echo "Could not detect Supabase project ref."
  echo "Set SUPABASE_PROJECT_REF or add SUPABASE_URL=https://PROJECT_REF.supabase.co to .env."
  exit 1
fi

if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" && "${SMARTKIT_SKIP_SUPABASE_UPDATE:-}" != "yes" ]]; then
  usage
  echo
  echo "Cannot update Supabase without SUPABASE_ACCESS_TOKEN."
  echo "Create token: Supabase Dashboard -> Account -> Access Tokens"
  exit 1
fi

require_command ollama "Install Ollama: https://ollama.com/download"
require_command node "Install Node.js, for example: brew install node"
require_command npx "Install Node.js/npm, for example: brew install node"
require_command cloudflared "Install cloudflared: brew install cloudflared"
require_command curl "curl is required."
require_command openssl "openssl is required to generate a proxy token."

log "SmartKit phone demo launcher"
echo "Project:             ${PROJECT_REF}"
echo "Model:               ${MODEL}"
echo "Ollama:              ${OLLAMA_URL}"
echo "Local proxy:         ${PROXY_URL}"
echo "Cloudflare protocol: ${CLOUDFLARED_PROTOCOL}"
echo "Logs:                ${LOG_DIR}"
echo

trap cleanup EXIT INT TERM

if curl -fsS "${OLLAMA_URL}/api/tags" >/dev/null 2>&1; then
  log "Ollama is already running."
else
  log "Starting Ollama..."
  : >"${LOG_DIR}/ollama.log"
  OLLAMA_HOST="127.0.0.1:11434" ollama serve >"${LOG_DIR}/ollama.log" 2>&1 &
  OLLAMA_PID="$!"
  printf '%s' "$OLLAMA_PID" >"${RUNTIME_DIR}/ollama.pid"
  wait_for_http "${OLLAMA_URL}/api/tags" "Ollama" 90
fi

if [[ "${SMARTKIT_SKIP_MODEL_PULL:-}" == "yes" ]]; then
  log "Skipping model pull because SMARTKIT_SKIP_MODEL_PULL=yes."
elif ollama list | awk 'NR > 1 { print $1 }' | grep -Fx "$MODEL" >/dev/null 2>&1; then
  log "Ollama model already exists: ${MODEL}"
else
  log "Pulling Ollama model: ${MODEL}"
  echo "This can take a while on the first run."
  ollama pull "$MODEL"
fi

kill_old_pid_file_process "${RUNTIME_DIR}/proxy.pid"
if lsof -ti tcp:"${PROXY_PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Port ${PROXY_PORT} is already in use."
  echo "Stop the old process or use another port:"
  echo "  SMARTKIT_PROXY_PORT=11501 SUPABASE_ACCESS_TOKEN=... $0"
  exit 1
fi

log "Starting SmartKit Ollama proxy..."
: >"${LOG_DIR}/proxy.log"
HOST=127.0.0.1 \
PORT="$PROXY_PORT" \
OLLAMA_BASE_URL="$OLLAMA_URL" \
OLLAMA_PROXY_TOKEN="$PROXY_TOKEN" \
node "${ROOT_DIR}/scripts/ollama_proxy.mjs" >"${LOG_DIR}/proxy.log" 2>&1 &
PROXY_PID="$!"
printf '%s' "$PROXY_PID" >"${RUNTIME_DIR}/proxy.pid"
sleep 1
if ! kill -0 "$PROXY_PID" >/dev/null 2>&1; then
  echo "SmartKit proxy stopped unexpectedly. Log:"
  tail -100 "${LOG_DIR}/proxy.log" || true
  exit 1
fi
wait_for_http "${PROXY_URL}/health" "SmartKit proxy" 30

kill_old_pid_file_process "${RUNTIME_DIR}/cloudflared.pid"
PUBLIC_URL=""
for tunnel_attempt in $(seq 1 5); do
  log "Starting Cloudflare quick tunnel (attempt ${tunnel_attempt}/5)..."
  : >"${LOG_DIR}/cloudflared.log"
  cloudflared tunnel \
    --no-autoupdate \
    --protocol "$CLOUDFLARED_PROTOCOL" \
    --url "$PROXY_URL" >"${LOG_DIR}/cloudflared.log" 2>&1 &
  TUNNEL_PID="$!"
  printf '%s' "$TUNNEL_PID" >"${RUNTIME_DIR}/cloudflared.pid"

  PUBLIC_URL=""
  for _ in $(seq 1 90); do
    PUBLIC_URL="$(grep -Eo 'https://[-a-zA-Z0-9.]+\.trycloudflare\.com' "${LOG_DIR}/cloudflared.log" | tail -1 || true)"
    if [[ -n "$PUBLIC_URL" ]]; then
      break
    fi
    if ! kill -0 "$TUNNEL_PID" >/dev/null 2>&1; then
      echo "cloudflared stopped unexpectedly. Log:"
      tail -80 "${LOG_DIR}/cloudflared.log" || true
      break
    fi
    log "Waiting for Cloudflare tunnel URL..."
    sleep 1
  done

  if [[ -z "$PUBLIC_URL" ]]; then
    log "Could not read Cloudflare tunnel URL on attempt ${tunnel_attempt}."
  else
    log "Cloudflare tunnel URL received:"
    echo "  ${PUBLIC_URL}"
    echo
    log "Checking public tunnel health..."
    if wait_for_public_tunnel "$PUBLIC_URL" 90; then
      break
    fi
    log "Cloudflare URL was not reachable; retrying with a new tunnel."
  fi

  if [[ -n "$TUNNEL_PID" ]] && kill -0 "$TUNNEL_PID" >/dev/null 2>&1; then
    kill "$TUNNEL_PID" >/dev/null 2>&1 || true
  fi
  TUNNEL_PID=""
  PUBLIC_URL=""
  rm -f "${RUNTIME_DIR}/cloudflared.pid"
  sleep 3
done

if [[ -z "$PUBLIC_URL" ]]; then
  echo "Could not create a reachable Cloudflare quick tunnel after 5 attempts."
  echo
  echo "Local proxy works here:"
  echo "  ${PROXY_URL}/health"
  echo
  echo "Last cloudflared log:"
  tail -100 "${LOG_DIR}/cloudflared.log" || true
  exit 1
fi

if [[ "${SMARTKIT_SKIP_SUPABASE_UPDATE:-}" == "yes" ]]; then
  log "Skipping Supabase update because SMARTKIT_SKIP_SUPABASE_UPDATE=yes."
else
  log "Updating Supabase AI secrets..."
  SUPABASE_ACCESS_TOKEN="$SUPABASE_ACCESS_TOKEN" npx supabase secrets set \
    "OLLAMA_BASE_URL=${PUBLIC_URL}" \
    "OLLAMA_MODEL=${MODEL}" \
    "OLLAMA_API_KEY=${PROXY_TOKEN}" \
    --project-ref "$PROJECT_REF"

  if [[ "$DEPLOY_FUNCTIONS" == "yes" ]]; then
    log "Redeploying Supabase AI functions..."
    SUPABASE_ACCESS_TOKEN="$SUPABASE_ACCESS_TOKEN" npx supabase functions deploy \
      ai-chat business-analysis \
      --project-ref "$PROJECT_REF" \
      --use-api
  else
    log "Skipping functions deploy because SMARTKIT_DEPLOY_FUNCTIONS=no."
  fi
fi

cat <<EOF

SmartKit local AI demo is running.

Phone APK path:
  ${ROOT_DIR}/SmartKit-teacher-arm64.apk

AI route now:
  Android phone APK -> Supabase -> ${PUBLIC_URL} -> this laptop -> Ollama ${MODEL}

Keep this terminal open while testing on the phone.
If the laptop sleeps, the phone AI will stop working.

Logs:
  ${LOG_DIR}/ollama.log
  ${LOG_DIR}/proxy.log
  ${LOG_DIR}/cloudflared.log

Stop:
  Press Ctrl+C in this terminal.

EOF

while kill -0 "$TUNNEL_PID" >/dev/null 2>&1; do
  sleep 60
  log "Still running. Phone AI tunnel: ${PUBLIC_URL}"
done

echo "Cloudflare tunnel stopped. Phone AI is no longer reachable."
exit 1
