type ChatMessage = {
  role: "system" | "user" | "assistant";
  content: string;
};

type OllamaChatOptions = {
  messages: ChatMessage[];
  model?: string;
  temperature?: number;
  numPredict?: number;
  numCtx?: number;
  timeoutMs?: number;
};

function sanitizeAssistantContent(content: string): string {
  return content.replace(/<think>[\s\S]*?<\/think>/gi, "").trim();
}

function envNumber(name: string, fallback: number): number {
  const value = Number(Deno.env.get(name));
  return Number.isFinite(value) && value > 0 ? value : fallback;
}

function compactText(value: string, max: number): string {
  const normalized = value.replace(/\s+/g, " ").trim();
  return normalized.length > max
    ? `${normalized.slice(0, max)}...`
    : normalized;
}

function compactMessages(messages: ChatMessage[]): ChatMessage[] {
  const system = messages.find((message) => message.role === "system");
  const recent = messages
    .filter((message) => message.role !== "system")
    .slice(-5);

  return [
    ...(system
      ? [{
        ...system,
        content: compactText(system.content, envNumber("OLLAMA_SYSTEM_MAX", 1000)),
      }]
      : []),
    ...recent.map((message) => ({
      ...message,
      content: compactText(message.content, envNumber("OLLAMA_MESSAGE_MAX", 360)),
    })),
  ];
}

export async function sendOllamaChat({
  messages,
  model,
  temperature = 0.25,
  numPredict = 700,
  numCtx = 3072,
  timeoutMs = 12000,
}: OllamaChatOptions): Promise<string> {
  const baseUrl = Deno.env.get("OLLAMA_BASE_URL") ?? "http://localhost:11434";
  const selectedModel = model ?? Deno.env.get("OLLAMA_MODEL") ?? "qwen3:latest";
  const apiKey = Deno.env.get("OLLAMA_API_KEY");
  const maxPredict = envNumber("OLLAMA_NUM_PREDICT_MAX", 80);
  const maxCtx = envNumber("OLLAMA_NUM_CTX_MAX", 1024);
  const effectiveMessages = compactMessages(messages);
  const lastUserIndex = effectiveMessages.findLastIndex((message) =>
    message.role === "user"
  );
  const optimizedMessages = effectiveMessages.map((message, index) => {
    if (index !== lastUserIndex || message.content.includes("/no_think")) {
      return message;
    }
    return {
      ...message,
      content:
        `${message.content}\n\n/no_think\nAnswer in the user's language. Keep it concise: 3-5 short bullets, under 700 characters.`,
    };
  });

  const response = await fetch(`${baseUrl.replace(/\/$/, "")}/api/chat`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(apiKey ? { Authorization: `Bearer ${apiKey}` } : {}),
    },
    body: JSON.stringify({
      model: selectedModel,
      messages: optimizedMessages,
      stream: false,
      think: false,
      keep_alive: Deno.env.get("OLLAMA_KEEP_ALIVE") ?? "24h",
      options: {
        temperature,
        top_p: 0.78,
        num_ctx: Math.min(numCtx, maxCtx),
        num_predict: Math.min(numPredict, maxPredict),
        repeat_penalty: 1.08,
      },
    }),
    signal: AbortSignal.timeout(timeoutMs),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Ollama request failed: ${response.status} ${errorText}`);
  }

  const data = await response.json();
  const content = sanitizeAssistantContent(data?.message?.content ?? "");
  if (content) return content;

  throw new Error(
    "Qwen3 did not finish a visible answer. Increase model capacity or generation limits.",
  );
}
