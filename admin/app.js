import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm";

const DEFAULT_SUPABASE_URL =
  window.SMARTKIT_ADMIN_CONFIG?.supabaseUrl ??
  localStorage.getItem("smartkit_admin_supabase_url") ??
  "https://gofpawwqtunhlnljujun.supabase.co";
const DEFAULT_SUPABASE_ANON_KEY =
  window.SMARTKIT_ADMIN_CONFIG?.supabaseAnonKey ??
  localStorage.getItem("smartkit_admin_supabase_anon") ??
  "";

const formatNumber = new Intl.NumberFormat("ru-RU");
const formatMoney = new Intl.NumberFormat("ru-RU", {
  style: "currency",
  currency: "KZT",
  maximumFractionDigits: 0,
});

const elements = {
  setupPanel: document.querySelector("#setupPanel"),
  dashboard: document.querySelector("#dashboard"),
  loginForm: document.querySelector("#loginForm"),
  supabaseUrl: document.querySelector("#supabaseUrl"),
  supabaseAnon: document.querySelector("#supabaseAnon"),
  email: document.querySelector("#email"),
  password: document.querySelector("#password"),
  setupHint: document.querySelector("#setupHint"),
  statusBadge: document.querySelector("#statusBadge"),
  logoutButton: document.querySelector("#logoutButton"),
  refreshButton: document.querySelector("#refreshButton"),
  overview: document.querySelector("#overview"),
  aiStats: document.querySelector("#aiStats"),
  sourceUsage: document.querySelector("#sourceUsage"),
  userStats: document.querySelector("#userStats"),
  latestUsers: document.querySelector("#latestUsers"),
  requestList: document.querySelector("#requestList"),
  commerceStats: document.querySelector("#commerceStats"),
};

let supabase = null;

function setStatus(text, ok = false) {
  elements.statusBadge.textContent = text;
  elements.statusBadge.classList.toggle("ok", ok);
}

function createSupabaseClient() {
  const url = elements.supabaseUrl.value.trim();
  const anon = elements.supabaseAnon.value.trim();
  if (!url || !anon) return null;
  localStorage.setItem("smartkit_admin_supabase_url", url);
  localStorage.setItem("smartkit_admin_supabase_anon", anon);
  supabase = createClient(url, anon);
  return supabase;
}

function metric(label, value, detail = "") {
  return `
    <article class="metric">
      <span>${label}</span>
      <strong>${value}</strong>
      <small>${detail}</small>
    </article>
  `;
}

function statRow(label, value) {
  return `<div class="stat-row"><span>${label}</span><strong>${value}</strong></div>`;
}

function showDashboard() {
  elements.setupPanel.classList.add("hidden");
  elements.dashboard.classList.remove("hidden");
  elements.logoutButton.classList.remove("hidden");
}

function showSetup() {
  elements.setupPanel.classList.remove("hidden");
  elements.dashboard.classList.add("hidden");
  elements.logoutButton.classList.add("hidden");
}

function renderDashboard(data) {
  const totals = data.totals ?? {};
  const ai = data.ai ?? {};
  const users = data.users ?? {};
  const commerce = data.commerce ?? {};

  elements.overview.innerHTML = [
    metric(
      "Пользователи",
      formatNumber.format(totals.users ?? 0),
      "Всего аккаунтов",
    ),
    metric(
      "AI запросы",
      formatNumber.format(totals.aiRequests ?? 0),
      "За все время",
    ),
    metric(
      "Сегодня",
      formatNumber.format(ai.todayRequests ?? 0),
      "AI обращений",
    ),
    metric(
      "Средняя задержка",
      `${formatNumber.format(ai.averageLatencyMs ?? 0)} мс`,
      "Сегодня",
    ),
    metric("Ошибки AI", `${Math.round((ai.errorRate ?? 0) * 100)}%`, "Сегодня"),
  ].join("");

  elements.aiStats.innerHTML = [
    statRow("Запросы сегодня", formatNumber.format(ai.todayRequests ?? 0)),
    statRow("Ошибки сегодня", formatNumber.format(ai.todayErrors ?? 0)),
    statRow(
      "Карточки товаров",
      formatNumber.format(ai.productSuggestions ?? 0),
    ),
    statRow(
      "Средняя задержка",
      `${formatNumber.format(ai.averageLatencyMs ?? 0)} мс`,
    ),
    statRow("Чаты", formatNumber.format(totals.chatThreads ?? 0)),
    statRow("Сообщения", formatNumber.format(totals.chatMessages ?? 0)),
  ].join("");

  const sources = Object.entries(ai.sourceUsage ?? {});
  elements.sourceUsage.innerHTML = sources.length
    ? sources
        .map(
          ([name, count]) =>
            `<span>${name}: ${formatNumber.format(count)}</span>`,
        )
        .join("")
    : "<span>Источники пока не использовались</span>";

  const roles = Object.entries(users.byRole ?? {});
  elements.userStats.innerHTML = roles.length
    ? roles
        .map(([role, count]) => statRow(role, formatNumber.format(count)))
        .join("")
    : statRow("Роли", "Нет данных");

  elements.latestUsers.innerHTML = (users.latest ?? [])
    .map(
      (user) => `
        <div>
          <span>${user.email ?? "unknown"}</span>
          <strong>${user.role ?? "role"}</strong>
        </div>
      `,
    )
    .join("");

  elements.commerceStats.innerHTML = [
    metric(
      "Товары",
      formatNumber.format(commerce.inventoryItems ?? 0),
      "В B2B каталоге",
    ),
    metric(
      "Публичные",
      formatNumber.format(commerce.publicItems ?? 0),
      "Витрина B2C",
    ),
    metric(
      "Низкий остаток",
      formatNumber.format(commerce.lowStock ?? 0),
      "Нужно пополнить",
    ),
    metric(
      "Продажи 7 дней",
      formatMoney.format(commerce.weeklyRevenue ?? 0),
      `${formatNumber.format(commerce.weeklySales ?? 0)} чеков`,
    ),
  ].join("");

  elements.requestList.innerHTML = (data.recentRequests ?? [])
    .map((request) => {
      const statusClass = request.status === "error" ? "badge error" : "badge";
      const sourceNames =
        (request.sourceNames ?? []).join(", ") || "нет источников";
      const products =
        (request.suggestedProducts ?? []).join(", ") || "нет карточек";
      return `
        <article class="request">
          <div class="request-header">
            <strong>${request.userEmail ?? "unknown"} · ${request.scope ?? "consumer"}</strong>
            <span class="${statusClass}">${request.status ?? "ok"}</span>
          </div>
          <p><strong>Запрос:</strong> ${request.prompt ?? ""}</p>
          <p><strong>Ответ:</strong> ${request.response ?? ""}</p>
          <div class="request-meta">
            <span>${request.model ?? "model"}</span>
            <span>${formatNumber.format(request.latencyMs ?? 0)} мс</span>
            <span>Источники: ${sourceNames}</span>
            <span>Товары: ${products}</span>
          </div>
        </article>
      `;
    })
    .join("");

  if (!elements.requestList.innerHTML.trim()) {
    elements.requestList.innerHTML = '<p class="hint">AI журнал пока пуст.</p>';
  }

  window.lucide?.createIcons();
}

async function loadDashboard() {
  if (!supabase) createSupabaseClient();
  if (!supabase) {
    setStatus("Нужна конфигурация");
    return;
  }

  setStatus("Загрузка...");
  elements.setupHint.textContent = "";

  const { data, error } = await supabase.functions.invoke("admin-dashboard", {
    method: "GET",
  });

  if (error) {
    showSetup();
    setStatus("Ошибка доступа");
    elements.setupHint.textContent =
      error.message || "Проверьте логин, пароль и запись в app_admins.";
    return;
  }

  renderDashboard(data);
  showDashboard();
  setStatus("Подключено", true);
}

async function init() {
  elements.supabaseUrl.value = DEFAULT_SUPABASE_URL;
  elements.supabaseAnon.value = DEFAULT_SUPABASE_ANON_KEY;

  if (DEFAULT_SUPABASE_URL && DEFAULT_SUPABASE_ANON_KEY) {
    createSupabaseClient();
    const { data } = await supabase.auth.getSession();
    if (data.session) {
      await loadDashboard();
    } else {
      showSetup();
    }
  }

  window.lucide?.createIcons();
}

elements.loginForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const client = createSupabaseClient();
  if (!client) return;

  setStatus("Вход...");
  elements.setupHint.textContent = "";

  const { error } = await client.auth.signInWithPassword({
    email: elements.email.value.trim(),
    password: elements.password.value,
  });

  if (error) {
    setStatus("Ошибка входа");
    elements.setupHint.textContent = error.message;
    return;
  }

  await loadDashboard();
});

elements.logoutButton.addEventListener("click", async () => {
  if (supabase) await supabase.auth.signOut();
  setStatus("Не подключено");
  showSetup();
});

elements.refreshButton.addEventListener("click", loadDashboard);

init();
