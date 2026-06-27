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
const formatDecimal = new Intl.NumberFormat("ru-RU", {
  maximumFractionDigits: 1,
});
const formatMoney = new Intl.NumberFormat("ru-RU", {
  style: "currency",
  currency: "KZT",
  maximumFractionDigits: 0,
});
const formatDateTime = new Intl.DateTimeFormat("ru-RU", {
  dateStyle: "short",
  timeStyle: "short",
});
const formatDay = new Intl.DateTimeFormat("ru-RU", {
  day: "2-digit",
  month: "short",
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
  analyticsPeriod: document.querySelector("#analyticsPeriod"),
  analyticsHint: document.querySelector("#analyticsHint"),
  analyticsOverview: document.querySelector("#analyticsOverview"),
  screenStats: document.querySelector("#screenStats"),
  featureStats: document.querySelector("#featureStats"),
  tabStats: document.querySelector("#tabStats"),
  transitionStats: document.querySelector("#transitionStats"),
  activeUsers: document.querySelector("#activeUsers"),
  eventCategoryFilter: document.querySelector("#eventCategoryFilter"),
  eventList: document.querySelector("#eventList"),
  engagementChart: document.querySelector("#engagementChart"),
  frequencyChart: document.querySelector("#frequencyChart"),
  platformChart: document.querySelector("#platformChart"),
  overview: document.querySelector("#overview"),
  aiStats: document.querySelector("#aiStats"),
  sourceUsage: document.querySelector("#sourceUsage"),
  userStats: document.querySelector("#userStats"),
  latestUsers: document.querySelector("#latestUsers"),
  requestList: document.querySelector("#requestList"),
  commerceStats: document.querySelector("#commerceStats"),
};

const charts = {};
let supabase = null;
let recentEvents = [];

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

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
      <span>${escapeHtml(label)}</span>
      <strong>${escapeHtml(value)}</strong>
      <small>${escapeHtml(detail)}</small>
    </article>
  `;
}

function statRow(label, value) {
  return `<div class="stat-row"><span>${escapeHtml(label)}</span><strong>${escapeHtml(value)}</strong></div>`;
}

function rankedRow(label, detail, events, users) {
  return `
    <div class="ranked-row">
      <div class="ranked-label">
        <strong>${escapeHtml(label)}</strong>
        <span>${escapeHtml(detail)}</span>
      </div>
      <div class="ranked-value">
        <strong>${formatNumber.format(events ?? 0)}</strong>
        <span>${formatNumber.format(users ?? 0)} польз.</span>
      </div>
    </div>
  `;
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

function renderChart(key, canvas, config) {
  if (!window.Chart || !canvas) return;
  charts[key]?.destroy();
  charts[key] = new window.Chart(canvas, config);
}

function chartOptions({ showLegend = true } = {}) {
  return {
    responsive: true,
    maintainAspectRatio: false,
    interaction: { mode: "index", intersect: false },
    plugins: {
      legend: {
        display: showLegend,
        labels: { usePointStyle: true, boxWidth: 8 },
      },
    },
    scales: {
      x: { grid: { display: false } },
      y: { beginAtZero: true, ticks: { precision: 0 } },
    },
  };
}

function renderProductAnalytics(analytics) {
  const totals = analytics.totals ?? {};
  const periodDays = analytics.periodDays ?? elements.analyticsPeriod.value;

  elements.analyticsHint.textContent = analytics.available
    ? `Данные только для app_admins, период: ${periodDays} дней`
    : `Аналитика ещё не подключена к базе: ${analytics.error ?? "примените миграцию"}`;

  elements.analyticsOverview.innerHTML = [
    metric("DAU", formatNumber.format(totals.dau ?? 0), "Активны сегодня"),
    metric("WAU", formatNumber.format(totals.wau ?? 0), "Активны за 7 дней"),
    metric("MAU", formatNumber.format(totals.mau ?? 0), "Активны за 30 дней"),
    metric(
      "Возврат",
      `${Math.round((totals.weeklyReturnRate ?? 0) * 100)}%`,
      "Вернулись из прошлой недели",
    ),
    metric(
      "Сессия",
      `${formatDecimal.format(totals.averageSessionMinutes ?? 0)} мин`,
      "Средняя длительность",
    ),
    metric(
      "Сессий / пользователь",
      formatDecimal.format(totals.sessionsPerUser ?? 0),
      `${formatNumber.format(totals.sessions ?? 0)} всего`,
    ),
    metric(
      "Событий / сессия",
      formatDecimal.format(totals.eventsPerSession ?? 0),
      `${formatNumber.format(totals.events ?? 0)} событий`,
    ),
    metric(
      "Активные",
      formatNumber.format(totals.activeUsers ?? 0),
      `За ${periodDays} дней`,
    ),
  ].join("");

  const daily = analytics.daily ?? [];
  renderChart("engagement", elements.engagementChart, {
    type: "line",
    data: {
      labels: daily.map((item) => formatDay.format(new Date(item.date))),
      datasets: [
        {
          label: "Пользователи",
          data: daily.map((item) => item.users ?? 0),
          borderColor: "#10b981",
          backgroundColor: "rgba(16, 185, 129, 0.12)",
          fill: true,
          tension: 0.3,
        },
        {
          label: "Сессии",
          data: daily.map((item) => item.sessions ?? 0),
          borderColor: "#2563eb",
          backgroundColor: "rgba(37, 99, 235, 0.08)",
          tension: 0.3,
        },
        {
          label: "События",
          data: daily.map((item) => item.events ?? 0),
          borderColor: "#f59e0b",
          backgroundColor: "rgba(245, 158, 11, 0.08)",
          tension: 0.3,
        },
      ],
    },
    options: chartOptions(),
  });

  const frequency = analytics.frequency ?? [];
  renderChart("frequency", elements.frequencyChart, {
    type: "bar",
    data: {
      labels: frequency.map((item) => `${item.bucket} сессий`),
      datasets: [
        {
          label: "Пользователи",
          data: frequency.map((item) => item.users ?? 0),
          backgroundColor: ["#a7f3d0", "#6ee7b7", "#34d399", "#059669"],
          borderRadius: 6,
        },
      ],
    },
    options: chartOptions({ showLegend: false }),
  });

  const platforms = analytics.platforms ?? [];
  renderChart("platform", elements.platformChart, {
    type: "doughnut",
    data: {
      labels: platforms.map((item) => item.name ?? "unknown"),
      datasets: [
        {
          data: platforms.map((item) => item.users ?? 0),
          backgroundColor: [
            "#10b981",
            "#2563eb",
            "#f59e0b",
            "#8b5cf6",
            "#ec4899",
            "#64748b",
          ],
          borderWidth: 0,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { position: "bottom", labels: { usePointStyle: true } },
      },
    },
  });

  elements.screenStats.innerHTML =
    (analytics.topScreens ?? [])
      .map((item) =>
        rankedRow(
          item.name ?? "unknown",
          "Просмотры экрана",
          item.events,
          item.users,
        ),
      )
      .join("") || '<p class="hint">Просмотров экранов пока нет.</p>';

  elements.featureStats.innerHTML =
    (analytics.topFeatures ?? [])
      .map((item) =>
        rankedRow(
          item.feature ?? "unknown",
          item.action ?? "used",
          item.events,
          item.users,
        ),
      )
      .join("") || '<p class="hint">Использований функций пока нет.</p>';

  elements.tabStats.innerHTML =
    (analytics.topTabs ?? [])
      .map((item) =>
        rankedRow(
          item.tab ?? "unknown",
          `Раздел: ${item.area ?? "app"}`,
          item.events,
          item.users,
        ),
      )
      .join("") || '<p class="hint">Переходов по вкладкам пока нет.</p>';

  elements.transitionStats.innerHTML =
    (analytics.transitions ?? [])
      .map((item) =>
        rankedRow(
          `${item.from ?? "unknown"} → ${item.to ?? "unknown"}`,
          "Переход между экранами",
          item.events,
          item.users,
        ),
      )
      .join("") || '<p class="hint">Переходов между экранами пока нет.</p>';

  const activeUsers = analytics.userActivity ?? [];
  elements.activeUsers.innerHTML = activeUsers.length
    ? `
      <table>
        <thead>
          <tr>
            <th>Пользователь</th>
            <th>Роль</th>
            <th>События</th>
            <th>Сессии</th>
            <th>Активные дни</th>
            <th>Последняя активность</th>
          </tr>
        </thead>
        <tbody>
          ${activeUsers
            .map(
              (user) => `
                <tr>
                  <td>${escapeHtml(user.email ?? "unknown")}</td>
                  <td>${escapeHtml(user.role ?? "unknown")}</td>
                  <td>${formatNumber.format(user.events ?? 0)}</td>
                  <td>${formatNumber.format(user.sessions ?? 0)}</td>
                  <td>${formatNumber.format(user.activeDays ?? 0)}</td>
                  <td>${escapeHtml(formatDate(user.lastSeen))}</td>
                </tr>
              `,
            )
            .join("")}
        </tbody>
      </table>
    `
    : '<p class="hint">Активности пользователей пока нет.</p>';

  recentEvents = analytics.recentEvents ?? [];
  const categories = [
    ...new Set(recentEvents.map((event) => event.category).filter(Boolean)),
  ].sort();
  const selectedCategory = elements.eventCategoryFilter.value;
  elements.eventCategoryFilter.innerHTML = [
    '<option value="">Все</option>',
    ...categories.map(
      (category) =>
        `<option value="${escapeHtml(category)}">${escapeHtml(category)}</option>`,
    ),
  ].join("");
  if (categories.includes(selectedCategory)) {
    elements.eventCategoryFilter.value = selectedCategory;
  }
  renderEvents();
}

function formatDate(value) {
  if (!value) return "—";
  const date = new Date(value);
  return Number.isNaN(date.valueOf()) ? "—" : formatDateTime.format(date);
}

function formatProperties(properties) {
  const entries = Object.entries(properties ?? {});
  if (!entries.length) return "";
  return entries
    .map(([key, value]) => `${escapeHtml(key)}: ${escapeHtml(value)}`)
    .join(" · ");
}

function renderEvents() {
  const category = elements.eventCategoryFilter.value;
  const filtered = category
    ? recentEvents.filter((event) => event.category === category)
    : recentEvents;

  elements.eventList.innerHTML =
    filtered
      .map((event) => {
        const transition =
          event.previousScreen && event.screenName
            ? `${event.previousScreen} → ${event.screenName}`
            : event.screenName || "Без экрана";
        const properties = formatProperties(event.properties);
        return `
          <article class="event-row">
            <div class="event-user">
              <strong>${escapeHtml(event.userEmail ?? "unknown")}</strong>
              <span>${escapeHtml(event.userRole ?? "unknown")} · ${escapeHtml(event.platform ?? "unknown")}</span>
            </div>
            <div class="event-main">
              <strong>${escapeHtml(event.eventName ?? "event")}</strong>
              <span>${escapeHtml(transition)}</span>
              ${properties ? `<div class="event-properties">${properties}</div>` : ""}
            </div>
            <time class="event-time">${escapeHtml(formatDate(event.occurredAt))}</time>
          </article>
        `;
      })
      .join("") || '<p class="hint">Событий по выбранному фильтру нет.</p>';
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
      "Организации",
      formatNumber.format(totals.organizations ?? 0),
      "B2B аккаунты",
    ),
    metric(
      "AI запросы",
      formatNumber.format(totals.aiRequests ?? 0),
      "За всё время",
    ),
    metric(
      "AI сегодня",
      formatNumber.format(ai.todayRequests ?? 0),
      "Обращений",
    ),
    metric("Ошибки AI", `${Math.round((ai.errorRate ?? 0) * 100)}%`, "Сегодня"),
  ].join("");

  renderProductAnalytics(data.productAnalytics ?? {});

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
            `<span>${escapeHtml(name)}: ${formatNumber.format(count)}</span>`,
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
          <span>${escapeHtml(user.email ?? "unknown")}</span>
          <strong>${escapeHtml(user.role ?? "role")}</strong>
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
            <strong>${escapeHtml(request.userEmail ?? "unknown")} · ${escapeHtml(request.scope ?? "consumer")}</strong>
            <span class="${statusClass}">${escapeHtml(request.status ?? "ok")}</span>
          </div>
          <p><strong>Запрос:</strong> ${escapeHtml(request.prompt ?? "")}</p>
          <p><strong>Ответ:</strong> ${escapeHtml(request.response ?? "")}</p>
          <div class="request-meta">
            <span>${escapeHtml(request.model ?? "model")}</span>
            <span>${formatNumber.format(request.latencyMs ?? 0)} мс</span>
            <span>Источники: ${escapeHtml(sourceNames)}</span>
            <span>Товары: ${escapeHtml(products)}</span>
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
    body: {
      analyticsDays: Number(elements.analyticsPeriod.value || 30),
    },
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
elements.analyticsPeriod.addEventListener("change", loadDashboard);
elements.eventCategoryFilter.addEventListener("change", renderEvents);

init();
