import http from 'node:http';

const port = Number(process.env.PORT ?? 11500);
const host = process.env.HOST ?? '127.0.0.1';
const ollamaBaseUrl = process.env.OLLAMA_BASE_URL ?? 'http://127.0.0.1:11435';
const proxyToken = process.env.OLLAMA_PROXY_TOKEN ?? '';
const ollamaKeepAlive = process.env.OLLAMA_KEEP_ALIVE ?? '24h';
const maxNumCtx = envInt('OLLAMA_PROXY_NUM_CTX_MAX', 4096);
const maxNumPredict = envInt('OLLAMA_PROXY_NUM_PREDICT_MAX', 1200);
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Authorization, Content-Type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};

function envInt(name, fallback) {
  const value = Number(process.env[name]);
  return Number.isFinite(value) && value > 0 ? Math.trunc(value) : fallback;
}

function clampInt(value, fallback, max) {
  const number = Number(value);
  if (!Number.isFinite(number) || number <= 0) return fallback;
  return Math.min(Math.trunc(number), max);
}

function normalizeOllamaBody(request, body) {
  if (
    request.method !== 'POST' ||
    !request.url?.startsWith('/api/chat') ||
    body.length === 0
  ) {
    return body;
  }

  try {
    const payload = JSON.parse(body.toString('utf8'));
    if (payload === null || Array.isArray(payload) || typeof payload !== 'object') {
      return body;
    }

    const options = payload.options && typeof payload.options === 'object'
      ? { ...payload.options }
      : {};

    payload.stream = false;
    if (typeof payload.think !== 'boolean') {
      delete payload.think;
    }
    payload.keep_alive = payload.keep_alive ?? ollamaKeepAlive;
    options.num_ctx = clampInt(options.num_ctx, maxNumCtx, maxNumCtx);
    options.num_predict = clampInt(
      options.num_predict,
      maxNumPredict,
      maxNumPredict,
    );
    options.top_p = Number.isFinite(Number(options.top_p)) ? options.top_p : 0.78;
    options.repeat_penalty = Number.isFinite(Number(options.repeat_penalty))
      ? options.repeat_penalty
      : 1.08;
    payload.options = options;

    return Buffer.from(JSON.stringify(payload));
  } catch (_) {
    return body;
  }
}

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
  const requestBody = normalizeOllamaBody(request, Buffer.concat(chunks));

  try {
    const upstream = await fetch(`${ollamaBaseUrl}${request.url}`, {
      method: request.method,
      headers: {
        'Content-Type': request.headers['content-type'] ?? 'application/json',
      },
      body: ['GET', 'HEAD'].includes(request.method ?? '')
        ? undefined
        : requestBody,
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
