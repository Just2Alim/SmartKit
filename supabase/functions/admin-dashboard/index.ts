import { createClient } from "npm:@supabase/supabase-js@2";

import { jsonResponse, preflightResponse } from "../_shared/cors.ts";

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`${name} is not configured`);
  return value;
}

function compact(value: string | null | undefined, max = 280): string {
  const text = String(value ?? "")
    .replace(/\s+/g, " ")
    .trim();
  return text.length > max ? `${text.slice(0, max)}...` : text;
}

function startOfDayIso(daysBack = 0): string {
  const date = new Date();
  date.setUTCHours(0, 0, 0, 0);
  date.setUTCDate(date.getUTCDate() - daysBack);
  return date.toISOString();
}

function average(values: number[]): number {
  if (!values.length) return 0;
  return Math.round(
    values.reduce((sum, value) => sum + value, 0) / values.length,
  );
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return preflightResponse();
  if (!["GET", "POST"].includes(request.method)) {
    return jsonResponse({ message: "Method not allowed" }, { status: 405 });
  }

  try {
    const jwt = (request.headers.get("Authorization") ?? "").replace(
      /^Bearer\s+/i,
      "",
    );
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
    const { data: adminRow } = await supabase
      .from("app_admins")
      .select("user_id")
      .eq("user_id", userId)
      .maybeSingle();

    if (!adminRow) {
      return jsonResponse(
        { message: "Admin access required" },
        { status: 403 },
      );
    }

    let analyticsDays = 30;
    if (request.method === "POST") {
      try {
        const body = await request.json();
        const requestedDays = Number(body?.analyticsDays ?? 30);
        analyticsDays = Number.isFinite(requestedDays)
          ? Math.min(Math.max(requestedDays, 7), 90)
          : 30;
      } catch (_) {
        analyticsDays = 30;
      }
    }

    const today = startOfDayIso(0);
    const weekStart = startOfDayIso(7);

    const [
      profileCount,
      threadCount,
      messageCount,
      aiCount,
      profilesResult,
      recentAiResult,
      todayAiResult,
      inventoryResult,
      salesResult,
      orgsResult,
      analyticsResult,
      recentEventsResult,
    ] = await Promise.all([
      supabase.from("profiles").select("id", { count: "exact", head: true }),
      supabase
        .from("chat_threads")
        .select("id", { count: "exact", head: true }),
      supabase
        .from("chat_messages")
        .select("id", { count: "exact", head: true }),
      supabase
        .from("ai_request_logs")
        .select("id", { count: "exact", head: true }),
      supabase
        .from("profiles")
        .select("id, email, role, created_at")
        .limit(2000),
      supabase
        .from("ai_request_logs")
        .select(
          "id, user_id, thread_id, scope, prompt, response, status, model, latency_ms, sources, product_suggestions, safety_flags, error_message, created_at",
        )
        .order("created_at", { ascending: false })
        .limit(50),
      supabase
        .from("ai_request_logs")
        .select("status, latency_ms, sources, product_suggestions, created_at")
        .gte("created_at", today)
        .limit(1000),
      supabase
        .from("b2b_inventory")
        .select("id, stock, min_stock, is_public, category, price")
        .limit(5000),
      supabase
        .from("b2b_sales")
        .select("id, total_amount, sale_date, organization_id")
        .gte("sale_date", weekStart)
        .limit(5000),
      supabase
        .from("organizations")
        .select("id", { count: "exact", head: true }),
      supabase.rpc("get_app_analytics_summary", {
        p_days: analyticsDays,
      }),
      supabase
        .from("app_analytics_events")
        .select(
          "id, user_id, session_id, event_name, category, screen_name, previous_screen, platform, properties, occurred_at",
        )
        .order("occurred_at", { ascending: false })
        .limit(250),
    ]);

    const profiles = profilesResult.data ?? [];
    const profileById = new Map(
      profiles.map((profile: Record<string, unknown>) => [
        String(profile.id),
        {
          email: String(profile.email ?? ""),
          role: String(profile.role ?? ""),
        },
      ]),
    );

    const usersByRole = profiles.reduce(
      (acc: Record<string, number>, profile) => {
        const role = String(profile.role ?? "unknown");
        acc[role] = (acc[role] ?? 0) + 1;
        return acc;
      },
      {},
    );

    const recentAi = recentAiResult.data ?? [];
    const todayAi = todayAiResult.data ?? [];
    const todayLatency = todayAi
      .map((row: Record<string, unknown>) => Number(row.latency_ms ?? 0))
      .filter((value) => value > 0);
    const todayErrors = todayAi.filter((row) => row.status === "error").length;
    const todaySuggestions = todayAi.reduce(
      (sum, row: Record<string, unknown>) => {
        const suggestions = Array.isArray(row.product_suggestions)
          ? row.product_suggestions.length
          : 0;
        return sum + suggestions;
      },
      0,
    );
    const sourceUsage = todayAi.reduce((acc: Record<string, number>, row) => {
      const sources = Array.isArray(row.sources) ? row.sources : [];
      for (const source of sources) {
        const name = String(
          (source as Record<string, unknown>).name ?? "source",
        );
        acc[name] = (acc[name] ?? 0) + 1;
      }
      return acc;
    }, {});

    const inventory = inventoryResult.data ?? [];
    const lowStock = inventory.filter(
      (item) => Number(item.stock ?? 0) <= Number(item.min_stock ?? 0),
    ).length;
    const publicItems = inventory.filter(
      (item) => item.is_public === true,
    ).length;
    const stockValue = inventory.reduce((sum, item) => {
      return sum + Number(item.stock ?? 0) * Number(item.price ?? 0);
    }, 0);

    const sales = salesResult.data ?? [];
    const weeklyRevenue = sales.reduce(
      (sum, sale) => sum + Number(sale.total_amount ?? 0),
      0,
    );

    const recentRequests = recentAi.map((row: Record<string, unknown>) => {
      const user = profileById.get(String(row.user_id));
      const sources = Array.isArray(row.sources) ? row.sources : [];
      const suggestions = Array.isArray(row.product_suggestions)
        ? row.product_suggestions
        : [];
      return {
        id: row.id,
        userId: row.user_id,
        userEmail: user?.email ?? "unknown",
        userRole: user?.role ?? "unknown",
        scope: row.scope,
        prompt: compact(String(row.prompt ?? ""), 320),
        response: compact(String(row.response ?? ""), 420),
        status: row.status,
        model: row.model,
        latencyMs: row.latency_ms,
        sourcesCount: sources.length,
        productSuggestionsCount: suggestions.length,
        sourceNames: sources
          .map((source) =>
            String((source as Record<string, unknown>).name ?? ""),
          )
          .filter(Boolean)
          .slice(0, 4),
        suggestedProducts: suggestions
          .map((item) => String((item as Record<string, unknown>).title ?? ""))
          .filter(Boolean)
          .slice(0, 4),
        safetyFlags: row.safety_flags,
        errorMessage: row.error_message,
        createdAt: row.created_at,
      };
    });

    const analytics =
      (analyticsResult.data as Record<string, unknown> | null) ?? {};
    const userActivity = Array.isArray(analytics.userActivity)
      ? analytics.userActivity.map((row: Record<string, unknown>) => {
          const profile = profileById.get(String(row.userId));
          return {
            ...row,
            email: profile?.email ?? "unknown",
            role: profile?.role ?? "unknown",
          };
        })
      : [];

    const recentEvents = (recentEventsResult.data ?? []).map(
      (row: Record<string, unknown>) => {
        const profile = profileById.get(String(row.user_id));
        return {
          id: row.id,
          userId: row.user_id,
          userEmail: profile?.email ?? "unknown",
          userRole: profile?.role ?? "unknown",
          sessionId: row.session_id,
          eventName: row.event_name,
          category: row.category,
          screenName: row.screen_name,
          previousScreen: row.previous_screen,
          platform: row.platform,
          properties: row.properties,
          occurredAt: row.occurred_at,
        };
      },
    );

    return jsonResponse({
      generatedAt: new Date().toISOString(),
      totals: {
        users: profileCount.count ?? profiles.length,
        organizations: orgsResult.count ?? 0,
        chatThreads: threadCount.count ?? 0,
        chatMessages: messageCount.count ?? 0,
        aiRequests: aiCount.count ?? 0,
      },
      ai: {
        todayRequests: todayAi.length,
        todayErrors,
        errorRate:
          todayAi.length === 0
            ? 0
            : Number((todayErrors / todayAi.length).toFixed(3)),
        averageLatencyMs: average(todayLatency),
        productSuggestions: todaySuggestions,
        sourceUsage,
      },
      users: {
        byRole: usersByRole,
        latest: profiles
          .sort((a, b) =>
            String(b.created_at ?? "").localeCompare(
              String(a.created_at ?? ""),
            ),
          )
          .slice(0, 10)
          .map((profile) => ({
            id: profile.id,
            email: profile.email,
            role: profile.role,
            createdAt: profile.created_at,
          })),
      },
      commerce: {
        inventoryItems: inventory.length,
        publicItems,
        lowStock,
        stockValue,
        weeklySales: sales.length,
        weeklyRevenue,
      },
      productAnalytics: {
        ...analytics,
        userActivity,
        recentEvents,
        available: !analyticsResult.error && !recentEventsResult.error,
        error:
          analyticsResult.error?.message ??
          recentEventsResult.error?.message ??
          null,
      },
      recentRequests,
    });
  } catch (error) {
    return jsonResponse(
      {
        message:
          error instanceof Error ? error.message : "Admin dashboard failed",
      },
      { status: 400 },
    );
  }
});
