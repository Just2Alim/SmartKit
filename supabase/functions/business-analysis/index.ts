import { createClient } from "npm:@supabase/supabase-js@2";

import { jsonResponse, preflightResponse } from "../_shared/cors.ts";
import { sendOllamaChat } from "../_shared/ollama.ts";

type InventoryRow = {
  name: string;
  category: string;
  stock: number;
  min_stock: number;
  price: number;
  expiry_date: string | null;
};

type LocationRow = {
  name: string;
  type: string;
  current_items: number;
  capacity: number;
  status: string;
};

type SaleRow = {
  total_amount: number;
  sale_date: string;
};

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`${name} is not configured`);
  }
  return value;
}

function buildBusinessContext(
  inventory: InventoryRow[],
  locations: LocationRow[],
  sales: SaleRow[],
): string {
  const lines = [
    "Ты бизнес-аналитик аптечного склада SmartKit.",
    "Отвечай кратко, по делу и только по данным ниже.",
    "",
    "--- Локации ---",
    ...locations.map((location) =>
      `${location.name} (${location.type}): ${location.current_items}/${location.capacity}, ${location.status}`
    ),
    "",
    "--- Склад ---",
    ...inventory.map((item) =>
      `${item.name}: ${item.category}, остаток ${item.stock}, минимум ${item.min_stock}, цена ${item.price}, срок ${item.expiry_date ?? "не указан"}`
    ),
    "",
    "--- Последние продажи ---",
    ...sales.map((sale) => `${sale.sale_date}: ${sale.total_amount}`),
  ];

  return lines.join("\n");
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return preflightResponse();
  }

  if (request.method !== "POST") {
    return jsonResponse({ message: "Method not allowed" }, { status: 405 });
  }

  try {
    const authHeader = request.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace(/^Bearer\s+/i, "");
    if (!jwt) {
      return jsonResponse({ message: "Authentication required" }, {
        status: 401,
      });
    }

    const supabase = createClient(
      requiredEnv("SUPABASE_URL"),
      requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
      { auth: { persistSession: false } },
    );

    const { data: userResult, error: userError } = await supabase.auth.getUser(
      jwt,
    );
    if (userError || !userResult.user) {
      return jsonResponse({ message: "Invalid token" }, { status: 401 });
    }

    const body = await request.json();
    const organizationId = String(body.organizationId ?? "").trim();
    const prompt = String(body.prompt ?? "").trim() ||
      "Проведи краткий анализ склада и продаж. Выдели 3 важных риска и действия.";

    if (!organizationId) {
      return jsonResponse({ message: "organizationId is required" }, {
        status: 400,
      });
    }

    const { data: membership } = await supabase
      .from("organization_members")
      .select("id")
      .eq("organization_id", organizationId)
      .eq("user_id", userResult.user.id)
      .eq("status", "active")
      .maybeSingle();

    if (!membership) {
      return jsonResponse({ message: "Organization access denied" }, {
        status: 403,
      });
    }

    const [{ data: inventory }, { data: locations }, { data: sales }] =
      await Promise.all([
        supabase
          .from("b2b_inventory")
          .select("name, category, stock, min_stock, price, expiry_date")
          .eq("organization_id", organizationId)
          .order("name", { ascending: true })
          .limit(160),
        supabase
          .from("b2b_locations")
          .select("name, type, current_items, capacity, status")
          .eq("organization_id", organizationId)
          .order("name", { ascending: true }),
        supabase
          .from("b2b_sales")
          .select("total_amount, sale_date")
          .eq("organization_id", organizationId)
          .order("sale_date", { ascending: false })
          .limit(30),
      ]);

    const content = await sendOllamaChat({
      messages: [
        {
          role: "system",
          content: buildBusinessContext(
            inventory ?? [],
            locations ?? [],
            sales ?? [],
          ),
        },
        { role: "user", content: prompt },
      ],
      temperature: 0.2,
    });

    return jsonResponse({ message: content });
  } catch (error) {
    return jsonResponse(
      {
        message: error instanceof Error
          ? error.message
          : "Business analysis failed",
      },
      { status: 400 },
    );
  }
});
