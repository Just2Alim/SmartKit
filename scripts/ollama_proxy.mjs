import http from 'node:http';

const port = Number(process.env.PORT ?? 11500);
const host = process.env.HOST ?? '127.0.0.1';
const ollamaBaseUrl = process.env.OLLAMA_BASE_URL ?? 'http://127.0.0.1:11435';
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
