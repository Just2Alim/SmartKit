type ChatMessage = {
  role: "system" | "user" | "assistant";
  content: string;
};

type OllamaChatOptions = {
  messages: ChatMessage[];
  model?: string;
  temperature?: number;
};

function sanitizeAssistantContent(content: string): string {
  return content.replace(/<think>[\s\S]*?<\/think>/gi, "").trim();
}

export async function sendOllamaChat({
  messages,
  model,
  temperature = 0.25,
}: OllamaChatOptions): Promise<string> {
  const baseUrl = Deno.env.get("OLLAMA_BASE_URL") ?? "http://localhost:11434";
  const selectedModel = model ?? Deno.env.get("OLLAMA_MODEL") ?? "qwen3:latest";
  const apiKey = Deno.env.get("OLLAMA_API_KEY");

  const response = await fetch(`${baseUrl.replace(/\/$/, "")}/api/chat`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(apiKey ? { Authorization: `Bearer ${apiKey}` } : {}),
    },
    body: JSON.stringify({
      model: selectedModel,
      messages,
      stream: false,
      options: {
        temperature,
        top_p: 0.85,
        num_ctx: 8192,
        num_predict: 4096,
      },
    }),
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
