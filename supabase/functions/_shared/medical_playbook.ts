export type CarePlaybook = {
  id: string;
  title: string;
  symptomTerms: string[];
  productTerms: string[];
  categoryTerms: string[];
  safeOptions: string[];
  selfCare: string[];
  caution: string[];
  redFlags: string[];
};

export type DemandSignal = {
  name: string;
  category: string;
  quantity: number;
  orders: number;
  lastSeen: string | null;
};

export const CARE_PLAYBOOKS: CarePlaybook[] = [
  {
    id: "pain_fever",
    title: "Боль или температура",
    symptomTerms: [
      "голов",
      "мигрен",
      "зуб",
      "бол",
      "ломот",
      "температур",
      "жар",
      "лихорад",
      "fever",
      "headache",
      "pain",
    ],
    productTerms: [
      "парацетамол",
      "ацетаминофен",
      "ибупрофен",
      "нурофен",
      "panadol",
      "paracetamol",
      "acetaminophen",
      "ibuprofen",
      "жаропониж",
      "обезбол",
    ],
    categoryTerms: ["обезбол", "жаропониж", "нпвс", "pain", "fever"],
    safeOptions: [
      "парацетамол/ацетаминофен или ибупрофен как безрецептурные варианты, если нет противопоказаний",
      "термометр и питьевой режим при температуре",
    ],
    selfCare: [
      "измерить температуру и оценить длительность симптомов",
      "проверить, нет ли в комбинированных средствах того же действующего вещества",
    ],
    caution: [
      "НПВС осторожно при язве, кровотечениях, болезнях почек, антикоагулянтах и беременности",
      "парацетамол нельзя дублировать в нескольких средствах и превышать инструкцию",
    ],
    redFlags: [
      "температура держится больше 3 дней или очень высокая",
      "сильная необычная головная боль, спутанность, сыпь, ригидность шеи",
      "боль в груди, одышка, слабость одной стороны тела",
    ],
  },
  {
    id: "allergy",
    title: "Аллергия, зуд, насморк",
    symptomTerms: [
      "аллерг",
      "зуд",
      "сып",
      "крапив",
      "чих",
      "насморк",
      "слез",
      "allergy",
      "rash",
      "itch",
    ],
    productTerms: [
      "цетиризин",
      "лоратадин",
      "дезлоратадин",
      "супрастин",
      "зодак",
      "зиртек",
      "cetirizine",
      "loratadine",
      "antihistamine",
    ],
    categoryTerms: ["аллерг", "antihistamine"],
    safeOptions: [
      "антигистаминные безрецептурные средства второго поколения как вариант для легких симптомов",
      "промывание носа солевым раствором при аллергическом насморке",
    ],
    selfCare: [
      "убрать вероятный аллерген и оценить, есть ли связь с едой, лекарством или укусом",
      "проверить, не вызывает ли выбранное средство сонливость",
    ],
    caution: [
      "при беременности, ГВ, детском возрасте и приеме седативных средств нужна консультация",
      "не сочетать несколько антигистаминных без назначения",
    ],
    redFlags: [
      "отек губ, языка или лица",
      "затруднение дыхания, свистящее дыхание",
      "быстро распространяющаяся сыпь после лекарства или укуса",
    ],
  },
  {
    id: "gi",
    title: "ЖКТ, диарея, изжога",
    symptomTerms: [
      "живот",
      "желуд",
      "изжог",
      "диаре",
      "понос",
      "тошнот",
      "рвот",
      "жкт",
      "stomach",
      "diarrhea",
      "heartburn",
      "nausea",
    ],
    productTerms: [
      "регидрон",
      "оральн",
      "смекта",
      "диосмектит",
      "сорбент",
      "омепразол",
      "антацид",
      "панкреатин",
      "rehydration",
      "diosmectite",
      "omeprazole",
      "antacid",
    ],
    categoryTerms: ["жкт", "сорбент", "изжог", "диаре", "digest"],
    safeOptions: [
      "раствор для оральной регидратации при потере жидкости",
      "сорбент/диосмектит при легкой диарее и антацид/средство от изжоги по инструкции",
    ],
    selfCare: [
      "пить небольшими порциями, следить за признаками обезвоживания",
      "не принимать противодиарейные средства при крови, высокой температуре или подозрении на инфекцию без врача",
    ],
    caution: [
      "сорбенты разносить по времени с другими лекарствами по инструкции",
      "частая рвота, кровь, черный стул или сильная боль требуют очной помощи",
    ],
    redFlags: [
      "кровь в стуле или черный стул",
      "признаки обезвоживания, сильная слабость",
      "острая сильная боль в животе или рвота, которая не дает пить",
    ],
  },
  {
    id: "cold_cough",
    title: "Простуда, горло, кашель",
    symptomTerms: [
      "простуд",
      "грипп",
      "каш",
      "горл",
      "насморк",
      "залож",
      "бронх",
      "cold",
      "flu",
      "cough",
      "sore throat",
    ],
    productTerms: [
      "парацетамол",
      "ибупрофен",
      "солев",
      "аквамарис",
      "амброксол",
      "ацетилцистеин",
      "пастилки",
      "спрей",
      "saline",
      "ambroxol",
      "acetylcysteine",
    ],
    categoryTerms: ["простуд", "каш", "лор", "горл", "cold", "cough"],
    safeOptions: [
      "солевой спрей/промывание носа, пастилки или местные средства для горла",
      "жаропонижающее/обезболивающее по инструкции при температуре или боли",
      "муколитик/отхаркивающее только если кашель влажный и это подходит по инструкции",
    ],
    selfCare: [
      "питье, отдых, проветривание, контроль температуры",
      "не дублировать парацетамол в порошках от простуды и отдельных таблетках",
    ],
    caution: [
      "антибиотики при простуде не начинать без врача",
      "детям и людям с астмой/ХОБЛ средства от кашля подбирать с врачом или фармацевтом",
    ],
    redFlags: [
      "одышка, боль в груди, посинение губ",
      "температура больше 3 дней или резкое ухудшение",
      "кровь в мокроте, выраженная слабость",
    ],
  },
  {
    id: "wound_burn",
    title: "Рана, порез, ожог",
    symptomTerms: [
      "рана",
      "порез",
      "ссад",
      "ожог",
      "кров",
      "царап",
      "wound",
      "cut",
      "burn",
    ],
    productTerms: [
      "хлоргексидин",
      "мирамистин",
      "антисеп",
      "бинт",
      "пластыр",
      "стериль",
      "chlorhexidine",
      "antiseptic",
      "bandage",
    ],
    categoryTerms: ["антисеп", "рана", "перевяз", "wound"],
    safeOptions: [
      "антисептик для обработки кожи и стерильная повязка/пластырь",
      "охлаждение ожога прохладной проточной водой первые минуты, без льда и масел",
    ],
    selfCare: [
      "промыть загрязнение чистой водой, затем закрыть стерильной повязкой",
      "проверить срок годности антисептика и стерильность перевязочных материалов",
    ],
    caution: [
      "не наносить агрессивные растворы в глубокую рану",
      "проверить прививку от столбняка при загрязненной ране",
    ],
    redFlags: [
      "сильное кровотечение, которое не останавливается",
      "глубокая, укушенная, сильно загрязненная рана",
      "ожог лица, кистей, гениталий, большой площади или с пузырями",
    ],
  },
];

const EMERGENCY_RULES: Array<[RegExp, string]> = [
  [/боль\s+в\s+груди|давит\s+в\s+груди|chest pain/i, "боль/давление в груди"],
  [/трудно\s+дыш|задых|одышк|не\s+могу\s+дыш|shortness of breath/i, "затруднение дыхания"],
  [/отек\s+(губ|язык|лица)|анафилак|anaphyl/i, "возможная тяжелая аллергическая реакция"],
  [/инсульт|перекос|онемел|слабость\s+рук|speech|stroke/i, "признаки инсульта"],
  [/судорог|потер(я|ял).*созн|seizure|unconscious/i, "судороги или потеря сознания"],
  [/кров(ь|отеч).*не\s+остан|сильн.*кров|heavy bleeding/i, "сильное кровотечение"],
  [/суицид|убить\s+себя|самоуб|suicid/i, "риск самоповреждения"],
];

export function normalizeMedicalText(value: string): string {
  return value
    .toLowerCase()
    .replace(/ё/g, "е")
    .replace(/\s+/g, " ")
    .trim();
}

export function containsAnyTerm(value: string, terms: string[]): boolean {
  const normalized = normalizeMedicalText(value);
  return terms.some((term) => normalized.includes(normalizeMedicalText(term)));
}

export function detectCarePlaybooks(userText: string): CarePlaybook[] {
  const normalized = normalizeMedicalText(userText);
  const matches = CARE_PLAYBOOKS.filter((playbook) =>
    playbook.symptomTerms.some((term) => normalized.includes(normalizeMedicalText(term)))
  );
  return matches.slice(0, 3);
}

export function detectEmergencyFlags(userText: string): string[] {
  const flags = new Set<string>();
  for (const [pattern, label] of EMERGENCY_RULES) {
    if (pattern.test(userText)) flags.add(label);
  }
  return [...flags];
}

export function playbookTerms(playbooks: CarePlaybook[]): string[] {
  return [
    ...new Set(
      playbooks.flatMap((playbook) => [
        ...playbook.productTerms,
        ...playbook.categoryTerms,
        ...playbook.symptomTerms,
      ]),
    ),
  ];
}

export function scoreTextForPlaybooks(text: string, playbooks: CarePlaybook[]): number {
  if (!playbooks.length) return 0;
  const normalized = normalizeMedicalText(text);
  let score = 0;
  for (const playbook of playbooks) {
    for (const term of playbook.productTerms) {
      if (normalized.includes(normalizeMedicalText(term))) score += 8;
    }
    for (const term of playbook.categoryTerms) {
      if (normalized.includes(normalizeMedicalText(term))) score += 5;
    }
  }
  return score;
}

export function aggregateDemandSignals(
  rows: Array<Record<string, unknown>>,
  playbooks: CarePlaybook[] = [],
  queryWords: string[] = [],
  limit = 6,
): DemandSignal[] {
  const terms = [
    ...playbookTerms(playbooks),
    ...queryWords,
  ].map(normalizeMedicalText).filter(Boolean);
  const groups = new Map<string, DemandSignal>();

  for (const row of rows) {
    const name = String(row.name ?? "").trim();
    const category = String(row.category ?? "").trim() || "Другое";
    if (!name && !category) continue;

    const quantity = Number(row.quantity ?? 1);
    const createdAt = String(row.created_at ?? row.createdAt ?? "").trim() || null;
    const haystack = normalizeMedicalText(`${name} ${category}`);
    const relevant = terms.length === 0 || terms.some((term) => haystack.includes(term));
    if (!relevant) continue;

    const key = `${normalizeMedicalText(category)}|${normalizeMedicalText(name)}`;
    const current = groups.get(key) ?? {
      name: name || category,
      category,
      quantity: 0,
      orders: 0,
      lastSeen: null,
    };
    current.quantity += Number.isFinite(quantity) && quantity > 0 ? quantity : 1;
    current.orders += 1;
    if (createdAt && (!current.lastSeen || createdAt > current.lastSeen)) {
      current.lastSeen = createdAt;
    }
    groups.set(key, current);
  }

  return [...groups.values()]
    .sort((a, b) => b.quantity - a.quantity || b.orders - a.orders)
    .slice(0, limit);
}

export function formatPlaybookContext(playbooks: CarePlaybook[]): string {
  if (!playbooks.length) {
    return "Типовой симптомный сценарий не распознан. Если пользователь спрашивает о лечении без симптомов, попроси уточнить симптомы, возраст, беременность/ГВ, хронические болезни и аллергии.";
  }

  return playbooks
    .map((playbook) =>
      [
        `• ${playbook.title}`,
        `  Безрецептурные варианты/категории: ${playbook.safeOptions.join("; ")}.`,
        `  Что проверить сейчас: ${playbook.selfCare.join("; ")}.`,
        `  Осторожность: ${playbook.caution.join("; ")}.`,
        `  Красные флаги: ${playbook.redFlags.join("; ")}.`,
      ].join("\n")
    )
    .join("\n");
}

export function formatDemandSignals(signals: DemandSignal[]): string {
  if (!signals.length) {
    return "Свежих B2C-сигналов спроса по этому запросу нет или данных пока мало.";
  }
  return signals
    .map((signal) =>
      `• ${signal.name} (${signal.category}): ${signal.quantity} шт. в ${signal.orders} заказах за период`
    )
    .join("\n");
}
