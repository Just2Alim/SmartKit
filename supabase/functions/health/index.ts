import { jsonResponse, preflightResponse } from "../_shared/cors.ts";

Deno.serve((request) => {
  if (request.method === "OPTIONS") {
    return preflightResponse();
  }

  return jsonResponse({
    ok: true,
    service: "smartkit",
    timestamp: new Date().toISOString(),
  });
});
