#!/usr/bin/env bash
set -euo pipefail

# Updates hosted Supabase Edge Function secrets so SmartKit uses the Google Cloud
# Ollama proxy instead of a laptop-local Ollama server.
#
# Required:
# - SUPABASE_PROJECT_REF
# - SUPABASE_ACCESS_TOKEN
# - OLLAMA_BASE_URL
# - OLLAMA_API_KEY
# - OLLAMA_MODEL
# - CONFIRM_SUPABASE_DEPLOY=yes

if [[ "${CONFIRM_SUPABASE_DEPLOY:-}" != "yes" ]]; then
  echo "Refusing to update Supabase hosted secrets without explicit confirmation."
  echo "Set CONFIRM_SUPABASE_DEPLOY=yes after checking the values."
  exit 1
fi

PROJECT_REF="${SUPABASE_PROJECT_REF:?Set SUPABASE_PROJECT_REF}"
ACCESS_TOKEN="${SUPABASE_ACCESS_TOKEN:?Set SUPABASE_ACCESS_TOKEN}"
BASE_URL="${OLLAMA_BASE_URL:?Set OLLAMA_BASE_URL, for example http://EXTERNAL_IP:11500}"
API_KEY="${OLLAMA_API_KEY:?Set OLLAMA_API_KEY to the proxy token}"
MODEL="${OLLAMA_MODEL:?Set OLLAMA_MODEL, for example qwen3:4b}"

SUPABASE_ACCESS_TOKEN="$ACCESS_TOKEN" npx supabase secrets set \
  "OLLAMA_BASE_URL=${BASE_URL}" \
  "OLLAMA_MODEL=${MODEL}" \
  "OLLAMA_API_KEY=${API_KEY}" \
  --project-ref "$PROJECT_REF"

SUPABASE_ACCESS_TOKEN="$ACCESS_TOKEN" npx supabase functions deploy \
  ai-chat business-analysis \
  --project-ref "$PROJECT_REF" \
  --use-api

echo "Supabase AI secrets updated and Edge Functions redeployed."
echo "SmartKit APK/web clients that use this Supabase project will now call:"
echo "  ${BASE_URL}"
