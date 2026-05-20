#!/usr/bin/env bash
set -euo pipefail

PROJECT_REF="${SUPABASE_PROJECT_REF:-gofpawwqtunhlnljujun}"

if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
  echo "Missing SUPABASE_ACCESS_TOKEN"
  echo "Create it in Supabase Dashboard -> Account -> Access Tokens."
  exit 1
fi

if [[ -z "${SUPABASE_ANON_KEY:-}" ]]; then
  echo "Missing SUPABASE_ANON_KEY"
  echo "Copy it from Project Settings -> API."
  exit 1
fi

if [[ -z "${SUPABASE_DB_PASSWORD:-}" ]]; then
  echo "Missing SUPABASE_DB_PASSWORD"
  echo "Use the project's database password from Project Settings -> Database."
  exit 1
fi

npx supabase link --project-ref "$PROJECT_REF" --password "$SUPABASE_DB_PASSWORD"
npx supabase db push --password "$SUPABASE_DB_PASSWORD"
npx supabase config push --project-ref "$PROJECT_REF" --yes

if [[ -n "${OLLAMA_BASE_URL:-}" ]]; then
  AI_PROXY_TOKEN="${OLLAMA_API_KEY:-${OLLAMA_PROXY_TOKEN:-}}"
  AI_SECRET_ARGS=(
    "OLLAMA_BASE_URL=${OLLAMA_BASE_URL}"
    "OLLAMA_MODEL=${OLLAMA_MODEL:-qwen3:latest}"
  )
  if [[ -n "$AI_PROXY_TOKEN" ]]; then
    AI_SECRET_ARGS+=("OLLAMA_API_KEY=${AI_PROXY_TOKEN}")
  fi

  npx supabase secrets set \
    "${AI_SECRET_ARGS[@]}"
else
  echo "Skipping OLLAMA_BASE_URL secret."
  echo "Set it before production AI usage; Edge Functions cannot call laptop localhost."
fi

npx supabase functions deploy health --project-ref "$PROJECT_REF" --use-api --no-verify-jwt
npx supabase functions deploy ai-chat business-analysis --project-ref "$PROJECT_REF" --use-api

cat > .env <<EOF
SUPABASE_URL=https://${PROJECT_REF}.supabase.co
SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}
SMARTKIT_API_BASE_URL=https://${PROJECT_REF}.supabase.co/functions/v1
OLLAMA_MODEL=${OLLAMA_MODEL:-qwen3:latest}
EOF

echo "Supabase remote setup completed for ${PROJECT_REF}."
echo "Run Flutter with:"
echo "flutter run -d chrome --dart-define-from-file=.env"
