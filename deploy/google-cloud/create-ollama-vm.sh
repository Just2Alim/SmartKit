#!/usr/bin/env bash
set -euo pipefail

# Creates a Google Compute Engine VM that runs:
# - Ollama on Docker
# - SmartKit's authenticated Ollama HTTP proxy on port 11500
#
# This script changes Google Cloud resources and can create billable resources.
# Run it only after setting CONFIRM_GCP_COSTS=yes.

if [[ "${CONFIRM_GCP_COSTS:-}" != "yes" ]]; then
  echo "Refusing to create Google Cloud resources without explicit confirmation."
  echo "Set CONFIRM_GCP_COSTS=yes after you understand that Compute Engine can be billable."
  exit 1
fi

if ! command -v gcloud >/dev/null 2>&1; then
  echo "Missing gcloud CLI. Install it first:"
  echo "https://docs.cloud.google.com/sdk/docs/install-sdk"
  exit 1
fi

PROJECT_ID="${GCP_PROJECT_ID:?Set GCP_PROJECT_ID, for example smartkit-demo-123}"
ZONE="${GCP_ZONE:-us-central1-a}"
REGION="${ZONE%-*}"
INSTANCE_NAME="${GCP_INSTANCE_NAME:-smartkit-ollama}"
MACHINE_TYPE="${GCP_MACHINE_TYPE:-e2-standard-4}"
BOOT_DISK_SIZE="${GCP_BOOT_DISK_SIZE:-80GB}"
NETWORK_TAG="${GCP_NETWORK_TAG:-smartkit-ai}"
MODEL="${OLLAMA_MODEL:-qwen3:4b}"
PROXY_TOKEN="${OLLAMA_PROXY_TOKEN:-}"

if [[ -z "$PROXY_TOKEN" ]]; then
  if command -v openssl >/dev/null 2>&1; then
    PROXY_TOKEN="$(openssl rand -hex 32)"
  else
    PROXY_TOKEN="$(python3 - <<'PY'
import secrets
print(secrets.token_hex(32))
PY
)"
  fi
fi

STARTUP_SCRIPT="$(mktemp)"
cat > "$STARTUP_SCRIPT" <<'STARTUP'
#!/bin/bash
set -euo pipefail

MODEL="__SMARTKIT_MODEL__"
PROXY_TOKEN="__SMARTKIT_PROXY_TOKEN__"

mkdir -p /opt/smartkit-ai

until docker info >/dev/null 2>&1; do
  sleep 2
done

cat > /opt/smartkit-ai/ollama_proxy.mjs <<'NODE'
import http from 'node:http';

const port = Number(process.env.PORT ?? 11500);
const host = process.env.HOST ?? '0.0.0.0';
const ollamaBaseUrl = process.env.OLLAMA_BASE_URL ?? 'http://smartkit-ollama:11434';
const proxyToken = process.env.OLLAMA_PROXY_TOKEN ?? '';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Authorization, Content-Type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};

const server = http.createServer(async (request, response) => {
  if (request.method === 'OPTIONS') {
    response.writeHead(204, corsHeaders);
    response.end();
    return;
  }

  if (request.method === 'GET' && request.url === '/health') {
    response.writeHead(200, {
      'Content-Type': 'application/json',
      ...corsHeaders,
    });
    response.end(JSON.stringify({ ok: true, service: 'smartkit-ollama-proxy' }));
    return;
  }

  if (proxyToken) {
    const expected = `Bearer ${proxyToken}`;
    if (request.headers.authorization !== expected) {
      response.writeHead(401, {
        'Content-Type': 'application/json',
        ...corsHeaders,
      });
      response.end(JSON.stringify({ message: 'Unauthorized' }));
      return;
    }
  }

  if (!request.url?.startsWith('/api/')) {
    response.writeHead(404, {
      'Content-Type': 'application/json',
      ...corsHeaders,
    });
    response.end(JSON.stringify({ message: 'Not found' }));
    return;
  }

  const chunks = [];
  for await (const chunk of request) {
    chunks.push(chunk);
  }

  try {
    const upstream = await fetch(`${ollamaBaseUrl}${request.url}`, {
      method: request.method,
      headers: {
        'Content-Type': request.headers['content-type'] ?? 'application/json',
      },
      body: ['GET', 'HEAD'].includes(request.method ?? '')
        ? undefined
        : Buffer.concat(chunks),
    });

    response.writeHead(upstream.status, {
      'Content-Type': upstream.headers.get('content-type') ?? 'application/json',
      ...corsHeaders,
    });
    response.end(Buffer.from(await upstream.arrayBuffer()));
  } catch (error) {
    response.writeHead(502, {
      'Content-Type': 'application/json',
      ...corsHeaders,
    });
    response.end(
      JSON.stringify({
        message: error instanceof Error ? error.message : 'Proxy failed',
      }),
    );
  }
});

server.listen(port, host, () => {
  console.log(`SmartKit Ollama proxy listening on http://${host}:${port}`);
});
NODE

docker network create smartkit-ai || true
docker volume create smartkit-ollama-data || true

docker rm -f smartkit-ollama smartkit-ollama-pull smartkit-ollama-proxy || true

docker run -d \
  --name smartkit-ollama \
  --restart unless-stopped \
  --network smartkit-ai \
  -e OLLAMA_HOST=0.0.0.0 \
  -v smartkit-ollama-data:/root/.ollama \
  ollama/ollama:latest

until docker run --rm --network smartkit-ai -e OLLAMA_HOST=http://smartkit-ollama:11434 ollama/ollama:latest list >/dev/null 2>&1; do
  sleep 2
done

docker run --rm \
  --name smartkit-ollama-pull \
  --network smartkit-ai \
  -e OLLAMA_HOST=http://smartkit-ollama:11434 \
  -v smartkit-ollama-data:/root/.ollama \
  ollama/ollama:latest pull "$MODEL"

docker run -d \
  --name smartkit-ollama-proxy \
  --restart unless-stopped \
  --network smartkit-ai \
  -p 11500:11500 \
  -e HOST=0.0.0.0 \
  -e PORT=11500 \
  -e OLLAMA_BASE_URL=http://smartkit-ollama:11434 \
  -e OLLAMA_PROXY_TOKEN="$PROXY_TOKEN" \
  -v /opt/smartkit-ai/ollama_proxy.mjs:/app/ollama_proxy.mjs:ro \
  node:22-alpine node /app/ollama_proxy.mjs
STARTUP

python3 - "$STARTUP_SCRIPT" "$MODEL" "$PROXY_TOKEN" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
model = sys.argv[2]
token = sys.argv[3]
text = path.read_text()
text = text.replace("__SMARTKIT_MODEL__", model)
text = text.replace("__SMARTKIT_PROXY_TOKEN__", token)
path.write_text(text)
PY

gcloud config set project "$PROJECT_ID" >/dev/null
gcloud services enable compute.googleapis.com --project "$PROJECT_ID"

if ! gcloud compute firewall-rules describe smartkit-allow-ai-proxy --project "$PROJECT_ID" >/dev/null 2>&1; then
  gcloud compute firewall-rules create smartkit-allow-ai-proxy \
    --project "$PROJECT_ID" \
    --network default \
    --direction INGRESS \
    --priority 1000 \
    --action ALLOW \
    --rules tcp:11500 \
    --source-ranges 0.0.0.0/0 \
    --target-tags "$NETWORK_TAG"
fi

if gcloud compute instances describe "$INSTANCE_NAME" --zone "$ZONE" --project "$PROJECT_ID" >/dev/null 2>&1; then
  echo "Instance $INSTANCE_NAME already exists. Updating startup script metadata."
  gcloud compute instances add-metadata "$INSTANCE_NAME" \
    --zone "$ZONE" \
    --project "$PROJECT_ID" \
    --metadata-from-file startup-script="$STARTUP_SCRIPT"
else
  gcloud compute instances create "$INSTANCE_NAME" \
    --project "$PROJECT_ID" \
    --zone "$ZONE" \
    --machine-type "$MACHINE_TYPE" \
    --image-family cos-stable \
    --image-project cos-cloud \
    --boot-disk-size "$BOOT_DISK_SIZE" \
    --boot-disk-type pd-balanced \
    --tags "$NETWORK_TAG" \
    --metadata-from-file startup-script="$STARTUP_SCRIPT"
fi

EXTERNAL_IP="$(
  gcloud compute instances describe "$INSTANCE_NAME" \
    --zone "$ZONE" \
    --project "$PROJECT_ID" \
    --format='get(networkInterfaces[0].accessConfigs[0].natIP)'
)"

rm -f "$STARTUP_SCRIPT"

cat <<EOF

SmartKit AI VM is being prepared.

Instance:      $INSTANCE_NAME
Project:       $PROJECT_ID
Zone:          $ZONE
Region:        $REGION
Machine type:  $MACHINE_TYPE
Model:         $MODEL

AI proxy URL:
  http://${EXTERNAL_IP}:11500

Proxy token:
  ${PROXY_TOKEN}

Wait 3-10 minutes for the VM to download the model, then test:
  curl http://${EXTERNAL_IP}:11500/health
  curl -X POST http://${EXTERNAL_IP}:11500/api/chat \\
    -H 'Authorization: Bearer ${PROXY_TOKEN}' \\
    -H 'Content-Type: application/json' \\
    --data '{"model":"${MODEL}","messages":[{"role":"user","content":"Ответь одним словом: работает?"}],"stream":false}'

Then set Supabase secrets with:
  OLLAMA_BASE_URL=http://${EXTERNAL_IP}:11500 \\
  OLLAMA_API_KEY=${PROXY_TOKEN} \\
  OLLAMA_MODEL=${MODEL} \\
  ./deploy/google-cloud/update-supabase-ai-secrets.sh

EOF
