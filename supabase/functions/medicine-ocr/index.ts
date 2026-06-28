import { createClient } from "npm:@supabase/supabase-js@2";

import { jsonResponse, preflightResponse } from "../_shared/cors.ts";
import { sendOllamaChat } from "../_shared/ollama.ts";

type OcrDraft = {
  rawText?: string;
  name?: string | null;
  category?: string | null;
  manufacturer?: string | null;
  description?: string | null;
  dosage?: string | null;
  packageSize?: string | null;
  barcode?: string | null;
  batchNumber?: string | null;
  form?: string | null;
  unitLabel?: string | null;
  storagePlace?: string | null;
  expiryDate?: string | null;
  source?: string | null;
  lookupMessage?: string | null;
  confidence?: number;
  needsReview?: boolean;
  suggestedStock?: number | null;
  suggestedMinStock?: number | null;
  suggestedPrice?: number | null;
};

type MedicineHint = {
  aliases: string[];
  name: string;
  category: string;
  dosage?: string;
  manufacturer?: string;
  minStock: number;
};

const HINTS: MedicineHint[] = [
  { aliases: ["нурофен", "nurofen", "ибупрофен", "ibuprofen"], name: "Нурофен", category: "Обезболивающее", dosage: "400 мг", manufacturer: "Reckitt Benckiser", minStock: 8 },
  { aliases: ["парацетамол", "paracetamol", "acetaminophen"], name: "Парацетамол", category: "Обезболивающее", dosage: "500 мг", minStock: 8 },
  { aliases: ["цетрин", "цетиризин", "cetrin", "cetirizine"], name: "Цетрин", category: "От аллергии", dosage: "10 мг", manufacturer: "Dr. Reddy's", minStock: 5 },
  { aliases: ["лоратадин", "loratadine"], name: "Лоратадин", category: "От аллергии", dosage: "10 мг", minStock: 5 },
  { aliases: ["супрастин", "suprastin"], name: "Супрастин", category: "От аллергии", manufacturer: "Egis", minStock: 5 },
  { aliases: ["смекта", "диосмектит", "smecta", "diosmectite"], name: "Смекта", category: "ЖКТ", manufacturer: "Ipsen", minStock: 5 },
  { aliases: ["регидрон", "rehydron"], name: "Регидрон", category: "ЖКТ", minStock: 5 },
  { aliases: ["омепразол", "omeprazole"], name: "Омепразол", category: "ЖКТ", dosage: "20 мг", minStock: 5 },
  { aliases: ["мирамистин", "miramistin"], name: "Мирамистин", category: "Антисептик", manufacturer: "Инфамед", minStock: 5 },
  { aliases: ["хлоргексидин", "chlorhexidine"], name: "Хлоргексидин", category: "Антисептик", minStock: 5 },
  { aliases: ["амброксол", "амбробене", "ambroxol", "ambrobene"], name: "Амброксол", category: "От простуды", dosage: "30 мг", minStock: 6 },
  { aliases: ["аквамарис", "aqua maris", "aquamaris"], name: "Аква Марис", category: "От простуды", minStock: 6 },
  { aliases: ["кеторол", "ketorol", "ketorolac", "кеторолак"], name: "Кеторол", category: "Обезболивающее", minStock: 5 },
  { aliases: ["энтеросгель", "enterosgel"], name: "Энтеросгель", category: "ЖКТ", minStock: 5 },
  { aliases: ["лоперамид", "loperamide", "имодиум", "imodium"], name: "Лоперамид", category: "ЖКТ", minStock: 4 },
];

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`${name} is not configured`);
  return value;
}

function clean(value: unknown): string | null {
  const text = String(value ?? "").replace(/\s+/g, " ").trim();
  return text.length ? text : null;
}

function normalize(value: string): string {
  return value.toLowerCase().replace(/ё/g, "е").replace(/\s+/g, " ").trim();
}

function repairOcrText(value: string): string {
  return value
    .replace(/\|/g, "I")
    .replace(/\bEXPIRY\b/gi, "EXP")
    .replace(/\bHYPOFEH\b/gi, "НУРОФЕН")
    .replace(/\bTAБЛETKИ\b/gi, "ТАБЛЕТКИ")
    .replace(/\bЦETPИH\b/gi, "ЦЕТРИН")
    .replace(/\s+/g, " ")
    .trim();
}

function findHint(text: string): MedicineHint | null {
  const normalized = normalize(text);
  return HINTS.find((hint) => hint.aliases.some((alias) => normalized.includes(alias))) ?? null;
}

function firstMatch(text: string, patterns: RegExp[]): string | null {
  for (const pattern of patterns) {
    const match = pattern.exec(text);
    const value = clean(match?.[1] ?? match?.[0]);
    if (value) return value;
  }
  return null;
}

function normalizeYear(year: string): number | null {
  const parsed = Number(year);
  if (!Number.isFinite(parsed)) return null;
  return parsed < 100 ? 2000 + parsed : parsed;
}

function parseExpiry(text: string): string | null {
  const full = /(?:exp\.?|expiry|годен до|срок годности|до)?\s*(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})/i.exec(text);
  if (full) {
    const day = Number(full[1]);
    const month = Number(full[2]);
    const year = normalizeYear(full[3]);
    if (year && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
      return new Date(Date.UTC(year, month - 1, day)).toISOString();
    }
  }
  const monthYear = /(?:exp\.?|expiry|годен до|срок годности|до)\s*(\d{1,2})[./-](\d{2,4})/i.exec(text);
  if (monthYear) {
    const month = Number(monthYear[1]);
    const year = normalizeYear(monthYear[2]);
    if (year && month >= 1 && month <= 12) {
      return new Date(Date.UTC(year, month, 0)).toISOString();
    }
  }
  return null;
}

function mapCategory(text: string): string {
  const lower = normalize(text);
  if (/ибупрофен|парацетамол|нурофен|кеторол|аспирин|обезбол|pain/.test(lower)) return "Обезболивающее";
  if (/цетиризин|цетрин|лоратадин|супрастин|аллерг|antihistamine/.test(lower)) return "От аллергии";
  if (/смекта|регидрон|омепразол|мезим|лоперамид|энтеросгель|уголь|жкт|diarrhea|stomach/.test(lower)) return "ЖКТ";
  if (/мирамистин|хлоргексидин|антисеп/.test(lower)) return "Антисептик";
  if (/каш|простуд|грипп|амброксол|аквамарис|cold|cough/.test(lower)) return "От простуды";
  if (/витамин|omega|омега/.test(lower)) return "Витамины";
  if (/антибиот|amoxicillin|azithromycin/.test(lower)) return "Антибиотик";
  return "Другое";
}

function inferForm(text: string): string | null {
  const lower = normalize(text);
  if (/табл|tablet/.test(lower)) return "Таблетки";
  if (/капсул|caps/.test(lower)) return "Капсулы";
  if (/сироп|syrup/.test(lower)) return "Сироп";
  if (/капли|drops/.test(lower)) return "Капли";
  if (/спрей|spray/.test(lower)) return "Спрей";
  if (/мазь|ointment/.test(lower)) return "Мазь";
  if (/крем|cream/.test(lower)) return "Крем";
  if (/саше|sachet|порош/.test(lower)) return "Порошок";
  return null;
}

function unitForForm(form: string | null): string {
  if (!form) return "шт";
  if (["Сироп", "Капли", "Спрей"].includes(form)) return "фл";
  if (form === "Порошок") return "саше";
  return "шт";
}

function parseDeterministic(rawText: string, barcode?: string | null): OcrDraft {
  const text = repairOcrText(rawText);
  const hint = findHint(text);
  const dosage = firstMatch(text, [
    /\b(\d+(?:[,.]\d+)?\s*(?:mg|мг|g|г|mcg|мкг|ml|мл|iu|ме|ед\.?|%))\b/i,
    /\b(\d+(?:[,.]\d+)?\s*(?:mg|мг)\s*\/\s*\d+(?:[,.]\d+)?\s*(?:ml|мл))\b/i,
  ])?.replace(",", ".") ?? hint?.dosage ?? null;
  const packageSize = firstMatch(text, [
    /((?:№\s?\d{1,4}|\b(?:n|no\.?|x)?\s?\d{1,4}\s*(?:табл\.?|таблет(?:ок|ки)?|капс\.?|капсул(?:а|ы)?|амп\.?|флак\.?|саше|шт\.?|pcs?)))\b/i,
    /(\b\d{1,4}\s*(?:x|х)\s*\d+(?:[,.]\d+)?\s*(?:mg|мг|ml|мл|g|г)\b)/i,
  ]);
  const foundBarcode = clean(barcode) ?? firstMatch(text, [/\b(\d{8,14})\b/]);
  const batchNumber = firstMatch(text, [
    /(?:lot|batch|серия|партия|сер\.?)\s*[:#№-]?\s*([A-ZА-Я0-9-]{3,24})/i,
    /\b([A-ZА-Я]{1,4}\d{3,12}[A-ZА-Я0-9-]*)\b/i,
  ]);
  const manufacturer = firstMatch(text, [
    /(?:manufacturer|made by|производитель|изготовитель)\s*[:\-]?\s*([A-Za-zА-Яа-я0-9 .,"«»-]{3,48})/i,
  ]) ?? hint?.manufacturer ?? null;
  const priceText = firstMatch(text, [
    /(?:цена|price|бағасы)\s*[:\-]?\s*(\d{2,7})\s*(?:₸|тг|тенге|kzt)?/i,
    /\b(\d{2,7})\s*(?:₸|тг|тенге|kzt)\b/i,
  ]);
  const form = inferForm(`${text} ${packageSize ?? ""}`);
  const name = hint?.name ?? firstNameCandidate(text);
  const category = hint?.category ?? mapCategory(text);
  const confidence = Math.min(
    0.98,
    0.2 +
      (hint ? 0.35 : 0) +
      (name ? 0.18 : 0) +
      (dosage ? 0.12 : 0) +
      (packageSize ? 0.08 : 0) +
      (foundBarcode ? 0.12 : 0) +
      (parseExpiry(text) ? 0.08 : 0),
  );
  return {
    rawText: text,
    name,
    category,
    manufacturer,
    dosage,
    packageSize,
    barcode: foundBarcode,
    batchNumber,
    form,
    unitLabel: unitForForm(form),
    storagePlace: /2-8|холодиль|refriger/i.test(text) ? "Холодильник" : "Домашняя аптечка",
    expiryDate: parseExpiry(text),
    description: name ? `${name} (${category})${dosage ? `, ${dosage}` : ""}${packageSize ? `, ${packageSize}` : ""}.` : null,
    source: "SmartKit server OCR parser",
    lookupMessage: confidence >= 0.75 ? "Поля заполнены автоматически, проверьте цену и остаток." : "Поля распознаны частично, проверьте перед сохранением.",
    confidence,
    needsReview: confidence < 0.75 || !name,
    suggestedStock: name ? 1 : null,
    suggestedMinStock: hint?.minStock ?? suggestedMinStock(category),
    suggestedPrice: priceText ? Number(priceText) : null,
  };
}

function firstNameCandidate(text: string): string | null {
  const rejected = /(exp|expiry|годен|срок|lot|batch|серия|партия|barcode|штрих|состав|хранить|табл|таблет|капс|mg|мг|ml|мл|№|\d{2}[./-]\d{2})/i;
  const lines = text.split(/\r?\n| {2,}/).map((line) => clean(line)).filter((line): line is string => !!line);
  const candidate = lines
    .filter((line) => !rejected.test(line))
    .filter((line) => /[A-Za-zА-Яа-яЁё]/.test(line))
    .sort((a, b) => b.length - a.length)[0];
  return candidate ? candidate.slice(0, 64) : null;
}

function suggestedMinStock(category: string | null): number | null {
  switch (category) {
    case "Обезболивающее":
    case "Жаропонижающее":
    case "От простуды":
      return 8;
    case "ЖКТ":
    case "От аллергии":
    case "Антисептик":
      return 5;
    case "Витамины":
      return 6;
    default:
      return category ? 4 : null;
  }
}

function parseJsonObject(value: string): Record<string, unknown> | null {
  const match = /\{[\s\S]*\}/.exec(value);
  if (!match) return null;
  try {
    const parsed = JSON.parse(match[0]);
    return parsed && typeof parsed === "object" && !Array.isArray(parsed)
      ? parsed as Record<string, unknown>
      : null;
  } catch (_) {
    return null;
  }
}

function mergeDrafts(...drafts: Array<OcrDraft | Record<string, unknown> | null | undefined>): OcrDraft {
  const result: OcrDraft = {};
  for (const draft of drafts) {
    if (!draft) continue;
    for (const [key, value] of Object.entries(draft)) {
      if (value === null || value === undefined || value === "") continue;
      if (result[key as keyof OcrDraft] === null || result[key as keyof OcrDraft] === undefined || result[key as keyof OcrDraft] === "") {
        (result as Record<string, unknown>)[key] = value;
      }
    }
  }
  result.confidence = Math.max(
    ...drafts.map((draft) => Number((draft as OcrDraft | undefined)?.confidence ?? 0)),
    Number(result.confidence ?? 0),
  );
  result.needsReview = (result.confidence ?? 0) < 0.78 || !result.name;
  return result;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return preflightResponse();
  if (request.method !== "POST") {
    return jsonResponse({ message: "Method not allowed" }, { status: 405 });
  }

  try {
    const authHeader = request.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace(/^Bearer\s+/i, "");
    if (!jwt) {
      return jsonResponse({ message: "Authentication required" }, { status: 401 });
    }

    const supabase = createClient(
      requiredEnv("SUPABASE_URL"),
      requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
      { auth: { persistSession: false } },
    );
    const { data: userResult, error: userError } = await supabase.auth.getUser(jwt);
    if (userError || !userResult.user) {
      return jsonResponse({ message: "Invalid token" }, { status: 401 });
    }

    const body = await request.json();
    const rawText = String(body.rawText ?? body.text ?? "").trim();
    if (rawText.length < 3) {
      return jsonResponse({ message: "rawText is required" }, { status: 400 });
    }

    const localDraft = (body.localDraft && typeof body.localDraft === "object")
      ? body.localDraft as Record<string, unknown>
      : null;
    const deterministic = parseDeterministic(rawText, clean(body.barcode));
    let aiDraft: Record<string, unknown> | null = null;

    try {
      const content = await sendOllamaChat({
        messages: [
          {
            role: "system",
            content:
              "Ты точный JSON-парсер OCR аптечных упаковок RU/KZ/EN. Верни только JSON без markdown. Поля: name, category, manufacturer, dosage, packageSize, barcode, batchNumber, form, unitLabel, storagePlace, expiryDate ISO или null, suggestedStock, suggestedMinStock, suggestedPrice, confidence 0..1, needsReview. Не выдумывай поле, если его нет.",
          },
          {
            role: "user",
            content:
              `OCR text:\n${rawText.slice(0, 5000)}\n\nLocal draft:\n${JSON.stringify(localDraft ?? deterministic).slice(0, 2500)}`,
          },
        ],
        temperature: 0.05,
        numPredict: 420,
        numCtx: 4096,
        timeoutMs: 0,
      });
      aiDraft = parseJsonObject(content);
    } catch (_) {
      aiDraft = null;
    }

    const result = mergeDrafts(aiDraft, deterministic, localDraft, {
      source: aiDraft ? "SmartKit AI OCR parser + local parser" : deterministic.source,
    });
    return jsonResponse({ result });
  } catch (error) {
    return jsonResponse(
      { message: error instanceof Error ? error.message : "OCR parsing failed" },
      { status: 400 },
    );
  }
});
