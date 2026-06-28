import { createClient } from "npm:@supabase/supabase-js@2";

import { jsonResponse, preflightResponse } from "../_shared/cors.ts";
import { sendOllamaChat } from "../_shared/ollama.ts";
import {
  aggregateDemandSignals,
  CarePlaybook,
  DemandSignal,
  detectCarePlaybooks,
  detectEmergencyFlags,
  formatDemandSignals,
  formatPlaybookContext,
  playbookTerms,
  scoreTextForPlaybooks,
} from "../_shared/medical_playbook.ts";

type ChatMessage = {
  role: "system" | "user" | "assistant";
  content: string;
};

type CatalogRow = {
  id: string;
  organization_id: string;
  name: string;
  category: string;
  description: string | null;
  manufacturer: string | null;
  dosage: string | null;
  package_size: string | null;
  barcode: string | null;
  batch_number: string | null;
  stock: number;
  min_stock: number;
  price: number;
  location_id: string | null;
  expiry_date: string | null;
  created_at: string;
  updated_at: string | null;
};

type KnowledgeRow = {
  topic: string;
  generic_name: string | null;
  brand_names: string[];
  summary: string;
  safety_notes: string;
  source_name: string;
  source_url: string;
  evidence_level: string;
  metadata: Record<string, unknown>;
};

type SourceReference = {
  name: string;
  url: string;
  type: string;
  summary?: string;
};

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`${name} is not configured`);
  return value;
}

function normalizeMessages(body: Record<string, unknown>): ChatMessage[] {
  const messages = Array.isArray(body.messages) ? body.messages : [];
  const normalized = messages
    .filter(
      (message): message is Record<string, unknown> =>
        typeof message === "object" && message !== null,
    )
    .map((message) => ({
      role: message.role as ChatMessage["role"],
      content: String(message.content ?? ""),
    }))
    .filter(
      (message) =>
        ["system", "user", "assistant"].includes(message.role) &&
        message.content.trim().length > 0,
    );

  if (normalized.length > 0) return normalized;

  const text = String(body.message ?? "").trim();
  if (!text) throw new Error("message or messages is required");
  return [{ role: "user", content: text }];
}

function latestUserText(messages: ChatMessage[]): string {
  return [...messages].reverse().find((m) => m.role === "user")?.content ?? "";
}

function compactText(value: string, max = 900): string {
  const normalized = value.replace(/\s+/g, " ").trim();
  return normalized.length > max
    ? `${normalized.slice(0, max)}...`
    : normalized;
}

function formatPrice(value: number): string {
  return `${new Intl.NumberFormat("ru-RU").format(value)} ₸`;
}

function words(value: string): string[] {
  return value
    .toLowerCase()
    .replace(/ё/g, "е")
    .split(/[^a-zа-яәғқңөұүһі0-9]+/i)
    .map((part) => part.trim())
    .filter((part) => part.length >= 3);
}

function medicalAliases(text: string): string[] {
  const lower = text.toLowerCase().replace(/ё/g, "е");
  const result = new Set<string>();
  const entries: Array<[RegExp, string[]]> = [
    [/голов|мигрен|боль|болит/i, ["ibuprofen", "acetaminophen"]],
    [/температур|жар|лихорад|простуд/i, ["acetaminophen", "ibuprofen"]],
    [/аллерг|сып|зуд|чих|насморк/i, ["cetirizine"]],
    [/изжог|желуд|кислот|гастр/i, ["omeprazole"]],
    [/рана|порез|антисеп|ожог/i, ["antiseptic"]],
    [/диаре|понос|жкт|живот/i, ["oral rehydration", "diosmectite"]],
    [/каш|горло|бронх/i, ["ambroxol"]],
  ];
  for (const [pattern, aliases] of entries) {
    if (pattern.test(lower)) aliases.forEach((alias) => result.add(alias));
  }
  for (const word of words(text)) result.add(word);
  return [...result].slice(0, 12);
}

function isRestrictedProduct(product: CatalogRow): boolean {
  const text =
    `${product.name} ${product.category} ${product.description ?? ""}`.toLowerCase();
  return [
    "антибиот",
    "гормон",
    "инсулин",
    "рецепт",
    "наркот",
    "opioid",
    "antibiotic",
    "prescription",
  ].some((keyword) => text.includes(keyword));
}

function scoreProduct(
  product: CatalogRow,
  queryWords: string[],
  playbooks: CarePlaybook[] = [],
): number {
  const haystack = [
    product.name,
    product.category,
    product.description ?? "",
    product.manufacturer ?? "",
    product.dosage ?? "",
  ]
    .join(" ")
    .toLowerCase()
    .replace(/ё/g, "е");

  let score = 0;
  score += scoreTextForPlaybooks(haystack, playbooks);

  for (const word of queryWords) {
    if (haystack.includes(word)) score += word.length > 5 ? 3 : 1;
  }

  if (/голов|боль|температур|жар/i.test(queryWords.join(" "))) {
    if (/обезбол|жаропониж|ибупрофен|нурофен|парацетамол/i.test(haystack)) {
      score += 8;
    }
  }
  if (/аллерг|сып|зуд/i.test(queryWords.join(" "))) {
    if (/аллерг|цетрин|супрастин/i.test(haystack)) score += 8;
  }
  if (/жкт|живот|диаре|изжог/i.test(queryWords.join(" "))) {
    if (/жкт|смекта|регидрон|омепразол|линекс/i.test(haystack)) score += 8;
  }
  if (/рана|порез|антисеп/i.test(queryWords.join(" "))) {
    if (/антисеп|мирамистин|хлоргексидин/i.test(haystack)) score += 8;
  }

  if (product.stock <= 0) score -= 100;
  if (isRestrictedProduct(product)) score -= 100;
  return score;
}

function productSuggestion(product: CatalogRow) {
  const subtitle = [
    product.category,
    product.dosage ?? "",
    product.package_size ?? "",
  ]
    .filter((part) => part.trim().length > 0)
    .join(" • ");

  return {
    id: product.id,
    organizationId: product.organization_id,
    title: product.name,
    subtitle,
    category: product.category,
    description: product.description,
    manufacturer: product.manufacturer,
    dosage: product.dosage,
    packageSize: product.package_size,
    stock: product.stock,
    maxStock: product.stock,
    priceValue: product.price,
    price: formatPrice(product.price),
    expiryDate: product.expiry_date,
    b2b_item: {
      id: product.id,
      userId: product.organization_id,
      name: product.name,
      category: product.category,
      description: product.description,
      manufacturer: product.manufacturer,
      barcode: product.barcode,
      batchNumber: product.batch_number,
      dosage: product.dosage,
      packageSize: product.package_size,
      stock: product.stock,
      minStock: product.min_stock,
      price: product.price,
      locationId: product.location_id,
      expiryDate: product.expiry_date,
      createdAt: product.created_at,
      updatedAt: product.updated_at,
    },
  };
}

function medicineContextText(value: Record<string, unknown>): string {
  return [
    value.name,
    value.category,
    value.dosage,
    value.notes,
  ]
    .filter((part) => part !== null && part !== undefined)
    .join(" ")
    .toLowerCase()
    .replace(/ё/g, "е");
}

function matchingHomeMedicines(
  homeMedicines: Array<Record<string, unknown>>,
  queryWords: string[],
  playbooks: CarePlaybook[],
): Array<Record<string, unknown>> {
  const terms = [...new Set([...queryWords, ...playbookTerms(playbooks)])]
    .map((term) => term.toLowerCase().replace(/ё/g, "е"))
    .filter((term) => term.length >= 3);

  if (!terms.length) return [];

  return homeMedicines
    .map((medicine) => {
      const haystack = medicineContextText(medicine);
      const score = terms.reduce(
        (sum, term) => sum + (haystack.includes(term) ? 1 : 0),
        0,
      ) + scoreTextForPlaybooks(haystack, playbooks);
      return { medicine, score };
    })
    .filter((entry) => entry.score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, 5)
    .map((entry) => entry.medicine);
}

function formatHomeMatches(matches: Array<Record<string, unknown>>): string {
  if (!matches.length) {
    return "Явных совпадений в домашней аптечке не найдено.";
  }
  return matches
    .map((m) =>
      `• ${m.name ?? ""} ${m.dosage ?? ""}, ${m.category ?? ""}, qty=${m.quantity ?? 0}, expiry=${m.expiry_date ?? "не указан"}`
    )
    .join("\n");
}

function buildConsumerFallback({
  userText,
  playbooks,
  emergencyFlags,
  homeMatches,
  products,
  demandSignals,
}: {
  userText: string;
  playbooks: CarePlaybook[];
  emergencyFlags: string[];
  homeMatches: Array<Record<string, unknown>>;
  products: ReturnType<typeof productSuggestion>[];
  demandSignals: DemandSignal[];
}): string {
  const lines: string[] = [];
  const hasSymptoms = playbooks.length > 0;

  if (emergencyFlags.length) {
    lines.push(
      `Похоже на красный флаг (${emergencyFlags.join(", ")}): лучше сразу вызвать 103/112 или обратиться за срочной помощью.`,
    );
  }

  if (!hasSymptoms) {
    lines.push(
      "Я не вижу конкретного симптома или задачи. Напишите, что беспокоит, возраст, беременность/ГВ, хронические болезни, аллергии и что уже есть в аптечке.",
    );
    lines.push(
      "Пока могу помочь проверить сроки, подобрать базовую аптечку, найти товар в каталоге или разобрать состав/инструкцию.",
    );
    return lines.join("\n");
  }

  const playbook = playbooks[0];
  lines.push(`По запросу ближе всего: ${playbook.title}. Это не диагноз, а безопасная справочная рамка.`);
  lines.push(`Что можно рассмотреть: ${playbook.safeOptions.join("; ")}. Дозировку и ограничения брать только из инструкции конкретного препарата.`);

  if (homeMatches.length) {
    const names = homeMatches
      .slice(0, 4)
      .map((m) => `${m.name ?? ""}${m.dosage ? ` ${m.dosage}` : ""}`.trim())
      .filter(Boolean)
      .join(", ");
    lines.push(`В вашей аптечке похоже подходят: ${names}. Проверьте срок годности, действующее вещество и противопоказания.`);
  } else {
    lines.push("В вашей аптечке я не нашел явного совпадения по этому запросу.");
  }

  if (products.length) {
    lines.push(
      `В магазине можно посмотреть карточки: ${products
        .slice(0, 3)
        .map((p) => p.title)
        .join(", ")}. Это варианты из каталога, не назначение лечения.`,
    );
  }

  if (demandSignals.length) {
    lines.push(
      `По свежему спросу чаще встречаются: ${demandSignals
        .slice(0, 3)
        .map((s) => `${s.name} (${s.quantity} шт.)`)
        .join(", ")}.`,
    );
  }

  lines.push(`Сейчас: ${playbook.selfCare.join("; ")}.`);
  lines.push(`К врачу/фармацевту: ${playbook.redFlags.join("; ")}.`);
  return lines.join("\n");
}

async function fetchOpenFdaLabel(
  term: string,
): Promise<SourceReference | null> {
  if (!/^[a-z][a-z\s-]{2,}$/i.test(term)) return null;
  const query = encodeURIComponent(`openfda.generic_name:"${term}"`);
  const url = `https://api.fda.gov/drug/label.json?search=${query}&limit=1`;
  try {
    const response = await fetch(url, {
      headers: { Accept: "application/json" },
      signal: AbortSignal.timeout(2500),
    });
    if (!response.ok) return null;
    const data = await response.json();
    const label = data.results?.[0];
    const summary = [
      label?.purpose?.[0],
      label?.indications_and_usage?.[0],
      label?.warnings?.[0],
    ]
      .filter(Boolean)
      .map((item) => compactText(String(item), 350))
      .join(" ");
    return {
      name: `openFDA drug label: ${term}`,
      url,
      type: "drug_label",
      summary,
    };
  } catch (_) {
    return null;
  }
}

async function fetchRxNorm(term: string): Promise<SourceReference | null> {
  if (!/^[a-z][a-z\s-]{2,}$/i.test(term)) return null;
  const url = `https://rxnav.nlm.nih.gov/REST/drugs.json?name=${encodeURIComponent(term)}`;
  try {
    const response = await fetch(url, {
      headers: { Accept: "application/json" },
      signal: AbortSignal.timeout(2500),
    });
    if (!response.ok) return null;
    const data = await response.json();
    const groups = data.drugGroup?.conceptGroup ?? [];
    const names = groups
      .flatMap((group: Record<string, unknown>) =>
        Array.isArray(group.conceptProperties)
          ? group.conceptProperties.map((item: Record<string, unknown>) =>
              String(item.name ?? ""),
            )
          : [],
      )
      .filter(Boolean)
      .slice(0, 4);
    return {
      name: `RxNorm: ${term}`,
      url,
      type: "drug_vocabulary",
      summary: names.length
        ? `Найдены связанные названия: ${names.join("; ")}`
        : "Справочник RxNorm проверен, точные активные продукты не найдены.",
    };
  } catch (_) {
    return null;
  }
}

async function fetchDailyMed(term: string): Promise<SourceReference | null> {
  if (!/^[a-z][a-z\s-]{2,}$/i.test(term)) return null;
  const url = `https://dailymed.nlm.nih.gov/dailymed/services/v2/spls.json?drug_name=${encodeURIComponent(
    term,
  )}&pagesize=1`;
  try {
    const response = await fetch(url, {
      headers: { Accept: "application/json" },
      signal: AbortSignal.timeout(2500),
    });
    if (!response.ok) return null;
    const data = await response.json();
    const label = data.data?.[0];
    if (!label) return null;
    return {
      name: `DailyMed label: ${term}`,
      url: label.setid
        ? `https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=${label.setid}`
        : url,
      type: "drug_label",
      summary: compactText(String(label.title ?? ""), 350),
    };
  } catch (_) {
    return null;
  }
}

async function fetchPubMed(topic: string): Promise<SourceReference | null> {
  const cleaned = words(topic).slice(0, 5).join(" ");
  if (cleaned.length < 4) return null;
  const searchUrl = `https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&retmode=json&retmax=2&term=${encodeURIComponent(
    `${cleaned} medication safety`,
  )}`;
  try {
    const search = await fetch(searchUrl, {
      headers: { Accept: "application/json" },
      signal: AbortSignal.timeout(2500),
    });
    if (!search.ok) return null;
    const searchData = await search.json();
    const ids: string[] = searchData.esearchresult?.idlist ?? [];
    if (!ids.length) {
      return { name: "PubMed", url: searchUrl, type: "scientific_literature" };
    }
    const summaryUrl = `https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=pubmed&retmode=json&id=${ids.join(
      ",",
    )}`;
    const summary = await fetch(summaryUrl, {
      headers: { Accept: "application/json" },
      signal: AbortSignal.timeout(2500),
    });
    if (!summary.ok) {
      return { name: "PubMed", url: searchUrl, type: "scientific_literature" };
    }
    const data = await summary.json();
    const titles = ids.map((id) => data.result?.[id]?.title).filter(Boolean);
    return {
      name: "PubMed literature",
      url: searchUrl,
      type: "scientific_literature",
      summary: titles.slice(0, 2).join(" | "),
    };
  } catch (_) {
    return null;
  }
}

function buildSystemPrompt({
  homeMedicines,
  homeMatches,
  knowledge,
  sources,
  products,
  playbooks,
  emergencyFlags,
  demandSignals,
}: {
  homeMedicines: Array<Record<string, unknown>>;
  homeMatches: Array<Record<string, unknown>>;
  knowledge: KnowledgeRow[];
  sources: SourceReference[];
  products: ReturnType<typeof productSuggestion>[];
  playbooks: CarePlaybook[];
  emergencyFlags: string[];
  demandSignals: DemandSignal[];
}): string {
  const medicineLines = homeMedicines.length
    ? homeMedicines
        .slice(0, 40)
        .map(
          (m) =>
            `• ${m.name ?? ""} ${m.dosage ?? ""}, ${m.category ?? ""}, qty=${m.quantity ?? 0}, expiry=${m.expiry_date ?? "не указан"}`,
        )
        .join("\n")
    : "Аптечка пользователя пуста или не заполнена.";

  const homeMatchLines = formatHomeMatches(homeMatches);

  const knowledgeLines = knowledge.length
    ? knowledge
        .map(
          (item) =>
            `• ${item.topic}: ${item.summary} Safety: ${item.safety_notes} Source: ${item.source_name} ${item.source_url}`,
        )
        .join("\n")
    : "Локальная база знаний не нашла точного совпадения.";

  const sourceLines = sources.length
    ? sources
        .map(
          (source) =>
            `• ${source.name} (${source.type}): ${source.summary ?? ""} ${source.url}`,
        )
        .join("\n")
    : "Внешние источники не вернули дополнительных данных.";

  const productLines = products.length
    ? products
        .map(
          (p) =>
            `• ${p.title}: ${p.subtitle}, цена ${p.price}, остаток ${p.stock}, id=${p.id}`,
        )
        .join("\n")
    : "Подходящих товаров в каталоге не найдено.";

  const careLines = formatPlaybookContext(playbooks);
  const demandLines = formatDemandSignals(demandSignals);
  const emergencyLines = emergencyFlags.length
    ? emergencyFlags.map((flag) => `• ${flag}`).join("\n")
    : "Явных экстренных флагов в тексте не найдено.";

  return `
Ты — аптечный помощник SmartKit по лекарствам, домашней аптечке, аптечному каталогу и безопасным следующим шагам.

Ты не должен отвечать одним шаблонным "обратитесь к врачу", если можно дать полезную безопасную рамку. Ты больше не ограничен только лекарствами из аптечки пользователя. Ты можешь:
1. Объяснять общие свойства и назначение безрецептурных категорий лекарств.
2. Сравнивать товары из аптечки и каталога SmartKit.
3. Предлагать конкретные карточки товаров из каталога, если они подходят под запрос.
4. Называть конкретные безрецептурные действующие вещества/категории как варианты, если нет красных флагов и это не рецептурное лечение.
5. Использовать контекст прошлых сообщений, домашней аптечки, каталога, свежего спроса и справочных источников.

Жесткие правила безопасности:
- Не ставь диагноз и не обещай лечение.
- Не назначай персональные дозировки, курсы, антибиотики, гормоны, сердечные, диабетические и другие рецептурные препараты. Вместо дозировки говори: "по инструкции к конкретному препарату".
- Для детей, беременности, ГВ, пожилых, хронических болезней, аллергий, полипрагмазии и сильных/долгих симптомов направляй к врачу или фармацевту.
- При экстренных симптомах: немедленно скорая 103/112.
- Если предлагаешь товар, объясни, что это категория/вариант из каталога, а не назначение лечения.
- Всегда проси проверить инструкцию, противопоказания, действующее вещество и срок годности.
- Не советуй принимать несколько средств с одинаковым действующим веществом.
- Отвечай на языке пользователя.
- Если симптом не указан, не угадывай лечение: попроси 1-3 уточнения и предложи, что можно проверить в аптечке/каталоге.
- Если вопрос странный или бессмысленный, спокойно уточни, что именно нужно сделать, и не выдумывай диагноз.

Текущая аптечка:
${medicineLines}

Совпадения в аптечке под текущий запрос:
${homeMatchLines}

Сценарии безопасной помощи:
${careLines}

Красные флаги, найденные в тексте:
${emergencyLines}

Свежий B2C-спрос по близким товарам/категориям:
${demandLines}

Релевантная локальная база знаний:
${knowledgeLines}

Проверенные внешние источники:
${sourceLines}

Доступные карточки товаров, которые можно предложить:
${productLines}

Формат ответа:
1. Короткий вывод по ситуации.
2. Что уже есть в аптечке и что проверить.
3. Какие безрецептурные варианты/категории можно рассмотреть, без персональной дозировки.
4. Какие карточки магазина подходят, если они есть.
5. Когда нужен врач/фармацевт или скорая.
`.trim();
}

function detectFastLanguage(userText: string): "ru" | "en" | "kk" {
  const lower = userText.toLowerCase();
  if (/[әғқңөұүһі]/i.test(lower) || /(сәлем|көмек|дәрі|қалай)/i.test(lower)) {
    return "kk";
  }
  if (/[a-z]/i.test(lower) && !/[а-яё]/i.test(lower)) return "en";
  return "ru";
}

function fastConsumerAnswer(userText: string): string | null {
  const lower = userText.toLowerCase().trim();
  const language = detectFastLanguage(userText);
  if (lower.length <= 40 && /^(привет|здравствуй|салам|сәлем|hello|hi|hey)/i.test(lower)) {
    if (language === "en") {
      return "Hi! I am SmartKit AI. I can check your first-aid kit, expiry dates, stock, explain general OTC medicine categories, and suggest safe next steps.";
    }
    if (language === "kk") {
      return "Сәлем! Мен SmartKit AI. Дәрі қобдишасын, жарамдылық мерзімдерін, қалдықтарды тексеріп, рецептісіз дәрі санаттарын түсіндіріп, қауіпсіз келесі қадамдарды ұсына аламын.";
    }
    return "Привет! Я SmartKit AI. Могу проверить аптечку, сроки годности, остатки, объяснить общие категории безрецептурных средств и подсказать безопасные следующие шаги.";
  }
  if (
    lower.length <= 140 &&
    /(что ты умеешь|чем поможешь|как пользоваться|помощь|help|what can you do|how to use|не істей аласың|көмек)/i
      .test(lower)
  ) {
    if (language === "en") {
      return "I can quickly check your first-aid kit and expiry dates, find low stock, help build a basic cart, explain general OTC categories, and flag when a doctor or pharmacist is needed.";
    }
    if (language === "kk") {
      return "Мен дәрі қобдишасын және жарамдылық мерзімдерін тез тексеремін, аз қалғандарын табамын, негізгі себет жинауға көмектесемін, рецептісіз дәрі санаттарын түсіндіремін және дәрігер/фармацевт керек кезде ескертемін.";
    }
    return "Я умею быстро проверять аптечку и сроки, находить низкие остатки, помогать с базовой корзиной, объяснять общие свойства безрецептурных категорий и подсказывать, когда лучше обратиться к врачу или фармацевту.";
  }
  return null;
}

function shouldFetchExternalSources(
  userText: string,
  knowledge: KnowledgeRow[],
  queryWords: string[],
): boolean {
  const lower = userText.toLowerCase();
  if (knowledge.length === 0 && queryWords.length === 0) return false;
  return /(инструкц|противопоказ|побоч|действующ|веществ|совмест|взаимодейств|исслед|источник|label|contraindication|side effect|interaction|source)/i
    .test(lower);
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return preflightResponse();
  if (request.method !== "POST") {
    return jsonResponse({ message: "Method not allowed" }, { status: 405 });
  }

  const started = Date.now();
  let logPayload: Record<string, unknown> | null = null;

  try {
    const authHeader = request.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace(/^Bearer\s+/i, "");
    if (!jwt)
      return jsonResponse(
        { message: "Authentication required" },
        { status: 401 },
      );

    const supabase = createClient(
      requiredEnv("SUPABASE_URL"),
      requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
      { auth: { persistSession: false } },
    );

    const { data: userResult, error: userError } =
      await supabase.auth.getUser(jwt);
    if (userError || !userResult.user) {
      return jsonResponse({ message: "Invalid token" }, { status: 401 });
    }

    const userId = userResult.user.id;
    const body = await request.json();
    const incomingMessages = normalizeMessages(body);
    const userText = latestUserText(incomingMessages);
    const scope = String(body.scope ?? "consumer");
    let threadId =
      typeof body.threadId === "string" && body.threadId.trim()
        ? body.threadId.trim()
        : "";

    if (!threadId) {
      const title = compactText(userText, 60) || "SmartKit AI чат";
      const { data: thread, error: threadError } = await supabase
        .from("chat_threads")
        .insert({
          user_id: userId,
          scope,
          title,
          last_message_at: new Date().toISOString(),
        })
        .select("id")
        .single();
      if (threadError) throw threadError;
      threadId = thread.id;
    }

    const carePlaybooks = detectCarePlaybooks(userText);
    const emergencyFlags = detectEmergencyFlags(userText);
    const queryWords = [
      ...new Set([
        ...medicalAliases(userText),
        ...playbookTerms(carePlaybooks),
      ]),
    ].slice(0, 28);
    const fastAnswer = fastConsumerAnswer(userText);
    if (fastAnswer != null) {
      await Promise.all([
        supabase.from("chat_messages").insert({
          thread_id: threadId,
          role: "user",
          content: userText,
          metadata: { scope, fast: true },
        }),
        supabase.from("chat_messages").insert({
          thread_id: threadId,
          role: "assistant",
          content: fastAnswer,
          metadata: { sources: [], productSuggestions: [], fast: true },
        }),
        supabase
          .from("chat_threads")
          .update({
            last_message_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          })
          .eq("id", threadId),
      ]);

      return jsonResponse({
        message: fastAnswer,
        threadId,
        productSuggestions: [],
        sources: [],
      });
    }

    const [
      { data: previousMessages },
      { data: homeMedicines },
      { data: catalog },
      { data: knowledgeData },
      { data: demandRows },
    ] = await Promise.all([
      supabase
        .from("chat_messages")
        .select("role, content")
        .eq("thread_id", threadId)
        .order("created_at", { ascending: false })
        .limit(8),
      supabase
        .from("medicines")
        .select("name, dosage, quantity, category, expiry_date, notes")
        .eq("user_id", userId)
        .order("created_at", { ascending: false })
        .limit(50),
      supabase
        .from("b2b_inventory")
        .select(
          "id, organization_id, name, category, description, manufacturer, dosage, package_size, barcode, batch_number, stock, min_stock, price, location_id, expiry_date, created_at, updated_at",
        )
        .eq("is_public", true)
        .gt("stock", 0)
        .order("name", { ascending: true })
        .limit(80),
      supabase
        .from("ai_medical_knowledge")
        .select(
          "topic, generic_name, brand_names, summary, safety_notes, source_name, source_url, evidence_level, metadata",
        )
        .limit(60),
      supabase
        .from("shop_order_items")
        .select("name, category, quantity, created_at")
        .gte(
          "created_at",
          new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString(),
        )
        .order("created_at", { ascending: false })
        .limit(180),
    ]);

    const homeMedicineRows = (homeMedicines ?? []) as Array<
      Record<string, unknown>
    >;
    const homeMatches = matchingHomeMedicines(
      homeMedicineRows,
      queryWords,
      carePlaybooks,
    );
    const demandSignals = aggregateDemandSignals(
      (demandRows ?? []) as Array<Record<string, unknown>>,
      carePlaybooks,
      queryWords,
      6,
    );

    const scoredProducts = ((catalog ?? []) as CatalogRow[])
      .map((product) => ({
        product,
        score: scoreProduct(product, queryWords, carePlaybooks),
      }))
      .filter((entry) => entry.score > 0)
      .sort((a, b) => b.score - a.score)
      .slice(0, 6)
      .map((entry) => productSuggestion(entry.product));

    const knowledge = ((knowledgeData ?? []) as KnowledgeRow[])
      .filter((item) => {
        const haystack = [
          item.topic,
          item.generic_name ?? "",
          ...(item.brand_names ?? []),
          String(item.metadata?.keywords ?? ""),
        ]
          .join(" ")
          .toLowerCase()
          .replace(/ё/g, "е");
        return queryWords.some((word) => haystack.includes(word));
      })
      .slice(0, 5);

    const shouldFetchSources = shouldFetchExternalSources(
      userText,
      knowledge,
      queryWords,
    );
    const termsForExternal = shouldFetchSources
      ? [
        ...new Set([
          ...(knowledge
            .map((item) => item.generic_name)
            .filter(Boolean) as string[]),
          ...queryWords.filter((term) => /^[a-z][a-z\s-]+$/i.test(term)),
        ]),
      ].slice(0, 1)
      : [];

    const externalResults = shouldFetchSources
      ? await Promise.all([
        ...termsForExternal.flatMap((term) => [
          fetchRxNorm(term),
          fetchDailyMed(term),
          fetchOpenFdaLabel(term),
        ]),
        fetchPubMed(userText),
      ])
      : [];

    const sources = [
      ...knowledge.map((item) => ({
        name: item.source_name,
        url: item.source_url,
        type: item.evidence_level,
        summary: item.summary,
      })),
      ...externalResults.filter(
        (item): item is SourceReference => item !== null,
      ),
    ].slice(0, 5);

    const system = buildSystemPrompt({
      homeMedicines: homeMedicineRows,
      homeMatches,
      knowledge,
      sources,
      products: scoredProducts,
      playbooks: carePlaybooks,
      emergencyFlags,
      demandSignals,
    });

    const history = (previousMessages ?? [])
      .reverse()
      .map((message: Record<string, string>) => ({
        role: message.role as ChatMessage["role"],
        content: message.content,
      }));

    const modelMessages: ChatMessage[] = [
      { role: "system", content: system },
      ...history,
      { role: "user", content: userText },
    ];

    await supabase.from("chat_messages").insert({
      thread_id: threadId,
      role: "user",
      content: userText,
      metadata: { scope },
    });

    let modelError: string | null = null;
    let content = "";
    try {
      content = await sendOllamaChat({
        messages: modelMessages,
        temperature:
          typeof body.temperature === "number" ? body.temperature : 0.22,
        numPredict: userText.length < 180 ? 900 : 1400,
        numCtx: 4096,
        timeoutMs: 0,
      });
    } catch (error) {
      modelError = error instanceof Error ? error.message : "Ollama unavailable";
      content = buildConsumerFallback({
        userText,
        playbooks: carePlaybooks,
        emergencyFlags,
        homeMatches,
        products: scoredProducts,
        demandSignals,
      });
    }

    await supabase.from("chat_messages").insert({
      thread_id: threadId,
      role: "assistant",
      content,
      metadata: {
        sources,
        productSuggestions: scoredProducts,
        fallback: modelError !== null,
      },
    });

    await supabase
      .from("chat_threads")
      .update({
        last_message_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq("id", threadId);

    logPayload = {
      user_id: userId,
      thread_id: threadId,
      scope,
      prompt: userText,
      response: content,
      status: modelError === null ? "ok" : "fallback",
      model: Deno.env.get("OLLAMA_MODEL") ?? "qwen3:latest",
      latency_ms: Date.now() - started,
      sources,
      product_suggestions: scoredProducts,
      safety_flags: emergencyFlags,
      error_message: modelError,
    };

    await supabase.from("ai_request_logs").insert(logPayload);

    return jsonResponse({
      message: content,
      threadId,
      productSuggestions: scoredProducts,
      sources,
    });
  } catch (error) {
    try {
      const supabase = createClient(
        requiredEnv("SUPABASE_URL"),
        requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
        { auth: { persistSession: false } },
      );
      await supabase.from("ai_request_logs").insert({
        ...(logPayload ?? {}),
        prompt: String(logPayload?.prompt ?? ""),
        response: "",
        status: "error",
        model: Deno.env.get("OLLAMA_MODEL") ?? "qwen3:latest",
        latency_ms: Date.now() - started,
        error_message:
          error instanceof Error ? error.message : "AI request failed",
      });
    } catch (_) {
      // Do not mask the original error.
    }

    return jsonResponse(
      { message: error instanceof Error ? error.message : "AI request failed" },
      { status: 400 },
    );
  }
});
