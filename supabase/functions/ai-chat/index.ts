import { jsonResponse, preflightResponse } from "../_shared/cors.ts";
import { sendOllamaChat } from "../_shared/ollama.ts";

type ChatMessage = {
  role: "system" | "user" | "assistant";
  content: string;
};

function normalizeMessages(body: Record<string, unknown>): ChatMessage[] {
  const messages = Array.isArray(body.messages) ? body.messages : [];
  const normalized = messages
    .filter((message): message is Record<string, unknown> =>
      typeof message === "object" && message !== null
    )
    .map((message) => ({
      role: message.role as ChatMessage["role"],
      content: String(message.content ?? ""),
    }))
    .filter((message) =>
      ["system", "user", "assistant"].includes(message.role) &&
      message.content.trim().length > 0
    );

  if (normalized.length > 0) {
    return normalized;
  }

  const text = String(body.message ?? "").trim();
  if (!text) {
    throw new Error("message or messages is required");
  }

  const system = String(body.system ?? "").trim();
  return [
    ...(system ? [{ role: "system" as const, content: system }] : []),
    { role: "user", content: text },
  ];
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return preflightResponse();
  }

  if (request.method !== "POST") {
    return jsonResponse({ message: "Method not allowed" }, { status: 405 });
  }

  try {
    const body = await request.json();
    const messages = normalizeMessages(body);
    const content = await sendOllamaChat({
      messages,
      temperature:
        typeof body.temperature === "number" ? body.temperature : 0.25,
    });

    return jsonResponse({ message: content });
  } catch (error) {
    return jsonResponse(
      { message: error instanceof Error ? error.message : "AI request failed" },
      { status: 400 },
    );
  }
});
