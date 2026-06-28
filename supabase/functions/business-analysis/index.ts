import { createClient } from "npm:@supabase/supabase-js@2";

import { jsonResponse, preflightResponse } from "../_shared/cors.ts";
import { sendOllamaChat } from "../_shared/ollama.ts";
import {
  aggregateDemandSignals,
  formatDemandSignals,
} from "../_shared/medical_playbook.ts";

type InventoryRow = {
  id: string;
  name: string;
  category: string;
  manufacturer: string | null;
  dosage: string | null;
  package_size: string | null;
  stock: number;
  min_stock: number;
  price: number;
  expiry_date: string | null;
  is_public: boolean;
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
  items: Array<Record<string, unknown>>;
};

type ShopDemandRow = {
  name: string;
  category: string | null;
  quantity: number;
  line_total?: number | null;
  created_at: string;
  organization_id?: string;
};

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`${name} is not configured`);
  }
  return value;
}

function formatMoney(value: number): string {
  return `${new Intl.NumberFormat("ru-RU").format(Math.round(value))} ₸`;
}

function daysUntil(dateText: string | null): number | null {
  if (!dateText) return null;
  const date = new Date(dateText);
  if (Number.isNaN(date.getTime())) return null;
  const today = new Date();
  return Math.ceil((date.getTime() - today.getTime()) / (24 * 60 * 60 * 1000));
}

function aggregateSaleItems(sales: SaleRow[]): Array<Record<string, unknown>> {
  const rows: Array<Record<string, unknown>> = [];
  for (const sale of sales) {
    const items = Array.isArray(sale.items) ? sale.items : [];
    for (const item of items) {
      rows.push({
        name: item.name ?? item.title ?? item.product_name ?? "",
        category: item.category ?? item.normalized_category ?? "",
        quantity: item.quantity ?? item.qty ?? 1,
        created_at: sale.sale_date,
      });
    }
  }
  return rows;
}

function revenueBetween(sales: SaleRow[], from: Date, to: Date): number {
  return sales.reduce((sum, sale) => {
    const date = new Date(sale.sale_date);
    if (date >= from && date < to) return sum + Number(sale.total_amount ?? 0);
    return sum;
  }, 0);
}

function buildDeterministicReport({
  inventory,
  locations,
  sales,
  ownDemand,
  marketDemand,
}: {
  inventory: InventoryRow[];
  locations: LocationRow[];
  sales: SaleRow[];
  ownDemand: ShopDemandRow[];
  marketDemand: ShopDemandRow[];
}): string {
  const now = new Date();
  const last30 = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
  const prev30 = new Date(now.getTime() - 60 * 24 * 60 * 60 * 1000);
  const revenue30 = revenueBetween(sales, last30, now);
  const revenuePrev = revenueBetween(sales, prev30, last30);
  const stockValue = inventory.reduce(
    (sum, item) => sum + Number(item.stock ?? 0) * Number(item.price ?? 0),
    0,
  );
  const lowStock = inventory
    .filter((item) => item.stock <= item.min_stock)
    .sort((a, b) => a.stock - b.stock)
    .slice(0, 6);
  const expired = inventory
    .filter((item) => {
      const days = daysUntil(item.expiry_date);
      return days !== null && days < 0;
    })
    .slice(0, 6);
  const expiring = inventory
    .filter((item) => {
      const days = daysUntil(item.expiry_date);
      return days !== null && days >= 0 && days <= 45;
    })
    .sort((a, b) => (daysUntil(a.expiry_date) ?? 999) - (daysUntil(b.expiry_date) ?? 999))
    .slice(0, 6);
  const ownSignals = aggregateDemandSignals(ownDemand as unknown as Array<Record<string, unknown>>, [], [], 5);
  const marketSignals = aggregateDemandSignals(marketDemand as unknown as Array<Record<string, unknown>>, [], [], 5);
  const trend =
    revenuePrev <= 0
      ? "недостаточно истории для процента роста"
      : `${Math.round(((revenue30 - revenuePrev) / revenuePrev) * 100)}% к предыдущим 30 дням`;

  return [
    "B2B-отчет SmartKit",
    `1. Выручка за 30 дней: ${formatMoney(revenue30)} (${trend}). Оценочная стоимость остатков: ${formatMoney(stockValue)}.`,
    `2. Критичные риски: просрочка ${expired.length}, сроки до 45 дней ${expiring.length}, низкий остаток ${lowStock.length}.`,
    lowStock.length
      ? `3. Дозаказ сегодня: ${lowStock.map((item) => `${item.name} до ${Math.max(item.min_stock * 2 - item.stock, item.min_stock)} шт.`).join("; ")}.`
      : "3. Дозаказ сегодня: явных товаров ниже минимума не найдено.",
    expiring.length
      ? `4. Сроки: вывести в приоритет продаж/перемещения ${expiring.map((item) => `${item.name} (${daysUntil(item.expiry_date)} дн.)`).join("; ")}.`
      : "4. Сроки: ближайших критичных сроков не найдено.",
    `5. B2C-спрос вашего магазина: ${ownSignals.length ? ownSignals.map((s) => `${s.name} ${s.quantity} шт.`).join("; ") : "данных мало"}.`,
    `6. Общий спрос SmartKit: ${marketSignals.length ? marketSignals.map((s) => `${s.name} ${s.quantity} шт.`).join("; ") : "данных мало"}.`,
    `7. Локации: ${locations.length ? locations.map((l) => `${l.name} ${l.current_items}/${l.capacity}`).join("; ") : "локации не заполнены"}.`,
  ].join("\n");
}

function buildBusinessContext(
  inventory: InventoryRow[],
  locations: LocationRow[],
  sales: SaleRow[],
  ownDemand: ShopDemandRow[],
  marketDemand: ShopDemandRow[],
): string {
  const now = new Date();
  const last30 = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
  const prev30 = new Date(now.getTime() - 60 * 24 * 60 * 60 * 1000);
  const revenue30 = revenueBetween(sales, last30, now);
  const revenuePrev = revenueBetween(sales, prev30, last30);
  const stockValue = inventory.reduce(
    (sum, item) => sum + Number(item.stock ?? 0) * Number(item.price ?? 0),
    0,
  );
  const lowStock = inventory
    .filter((item) => item.stock <= item.min_stock)
    .sort((a, b) => a.stock - b.stock)
    .slice(0, 20);
  const expired = inventory.filter((item) => {
    const days = daysUntil(item.expiry_date);
    return days !== null && days < 0;
  });
  const expiring = inventory
    .filter((item) => {
      const days = daysUntil(item.expiry_date);
      return days !== null && days >= 0 && days <= 45;
    })
    .sort((a, b) => (daysUntil(a.expiry_date) ?? 999) - (daysUntil(b.expiry_date) ?? 999))
    .slice(0, 20);
  const saleDemand = aggregateDemandSignals(aggregateSaleItems(sales), [], [], 10);
  const ownDemandSignals = aggregateDemandSignals(
    ownDemand as unknown as Array<Record<string, unknown>>,
    [],
    [],
    10,
  );
  const marketDemandSignals = aggregateDemandSignals(
    marketDemand as unknown as Array<Record<string, unknown>>,
    [],
    [],
    10,
  );
  const trend =
    revenuePrev <= 0
      ? "нет базы сравнения"
      : `${Math.round(((revenue30 - revenuePrev) / revenuePrev) * 100)}%`;

  const lines = [
    "Ты SmartKit Business Analyst для аптечного склада/аптеки.",
    "Сделай живой, конкретный отчет по данным, а не шаблон. Используй реальные названия, числа, риски и действия.",
    "Не обещай прибыль. Не советуй продавать рецептурные препараты, антибиотики или препараты с комплаенс-риском без рецепта.",
    "Если данных не хватает, прямо скажи, какие данные нужно начать собирать.",
    "",
    "--- KPI ---",
    `Товарных позиций: ${inventory.length}`,
    `Оценочная стоимость остатков: ${formatMoney(stockValue)}`,
    `Выручка 30 дней: ${formatMoney(revenue30)}`,
    `Выручка предыдущие 30 дней: ${formatMoney(revenuePrev)}; тренд: ${trend}`,
    `Низкий остаток: ${lowStock.length}; просрочено: ${expired.length}; срок до 45 дней: ${expiring.length}`,
    "",
    "--- Локации ---",
    ...locations.map((location) =>
      `${location.name} (${location.type}): ${location.current_items}/${location.capacity}, ${location.status}`
    ),
    "",
    "--- Низкий остаток ---",
    ...(lowStock.length
      ? lowStock.map((item) =>
        `${item.name}: остаток ${item.stock}, минимум ${item.min_stock}, цена ${item.price}, категория ${item.category}`
      )
      : ["Нет товаров ниже или на уровне минимума."]),
    "",
    "--- Сроки годности: просрочено/до 45 дней ---",
    ...(expired.length
      ? expired.slice(0, 12).map((item) =>
        `${item.name}: срок ${item.expiry_date}, остаток ${item.stock}, цена ${item.price}`
      )
      : ["Просроченные позиции не найдены."]),
    ...(expiring.length
      ? expiring.map((item) =>
        `${item.name}: ${daysUntil(item.expiry_date)} дней, остаток ${item.stock}, цена ${item.price}`
      )
      : ["Позиций со сроком до 45 дней не найдено."]),
    "",
    "--- Склад: все позиции ---",
    ...inventory.map((item) =>
      `${item.name}: ${item.category}, ${item.dosage ?? ""} ${item.package_size ?? ""}, производитель ${item.manufacturer ?? "не указан"}, остаток ${item.stock}, минимум ${item.min_stock}, цена ${item.price}, срок ${item.expiry_date ?? "не указан"}, публичный=${item.is_public}`
    ),
    "",
    "--- Последние продажи ---",
    ...sales.slice(0, 30).map((sale) => `${sale.sale_date}: ${sale.total_amount}, строк=${Array.isArray(sale.items) ? sale.items.length : 0}`),
    "",
    "--- Спрос из продаж B2B/POS ---",
    formatDemandSignals(saleDemand),
    "",
    "--- B2C-заказы именно этой аптеки ---",
    formatDemandSignals(ownDemandSignals),
    "",
    "--- Общий B2C-спрос SmartKit за 30 дней ---",
    formatDemandSignals(marketDemandSignals),
    "",
    "Формат отчета:",
    "1. Executive summary на 2-3 строки.",
    "2. Критичные риски сегодня: просрочка, сроки, низкий остаток, перегруженные локации.",
    "3. Дозаказ и перемещение: конкретные товары и примерные количества по минимуму/спросу.",
    "4. Ассортимент и спрос B2C: что добавить/поднять в каталоге, что не продвигать.",
    "5. План действий на 24 часа и на 7 дней.",
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

    const demandStart = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)
      .toISOString();
    const [{ data: inventory }, { data: locations }, { data: sales }, {
      data: ownDemand,
    }, { data: marketDemand }] = await Promise.all([
        supabase
          .from("b2b_inventory")
          .select(
            "id, name, category, manufacturer, dosage, package_size, stock, min_stock, price, expiry_date, is_public",
          )
          .eq("organization_id", organizationId)
          .order("name", { ascending: true })
          .limit(200),
        supabase
          .from("b2b_locations")
          .select("name, type, current_items, capacity, status")
          .eq("organization_id", organizationId)
          .order("name", { ascending: true }),
        supabase
          .from("b2b_sales")
          .select("total_amount, sale_date, items")
          .eq("organization_id", organizationId)
          .order("sale_date", { ascending: false })
          .limit(120),
        supabase
          .from("shop_order_items")
          .select("name, category, quantity, line_total, created_at, organization_id")
          .eq("organization_id", organizationId)
          .gte("created_at", demandStart)
          .order("created_at", { ascending: false })
          .limit(250),
        supabase
          .from("shop_order_items")
          .select("name, category, quantity, line_total, created_at, organization_id")
          .gte("created_at", demandStart)
          .order("created_at", { ascending: false })
          .limit(500),
      ]);

    const inventoryRows = (inventory ?? []) as InventoryRow[];
    const locationRows = (locations ?? []) as LocationRow[];
    const saleRows = (sales ?? []) as SaleRow[];
    const ownDemandRows = (ownDemand ?? []) as ShopDemandRow[];
    const marketDemandRows = (marketDemand ?? []) as ShopDemandRow[];

    let fallback = false;
    let content = "";
    try {
      content = await sendOllamaChat({
        messages: [
          {
            role: "system",
            content: buildBusinessContext(
              inventoryRows,
              locationRows,
              saleRows,
              ownDemandRows,
              marketDemandRows,
            ),
          },
          { role: "user", content: prompt },
        ],
        temperature: 0.18,
        numPredict: prompt.length < 180 ? 900 : 1200,
        numCtx: 4096,
        timeoutMs: 25000,
      });
    } catch (_) {
      fallback = true;
      content = buildDeterministicReport({
        inventory: inventoryRows,
        locations: locationRows,
        sales: saleRows,
        ownDemand: ownDemandRows,
        marketDemand: marketDemandRows,
      });
    }

    return jsonResponse({ message: content, fallback });
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
