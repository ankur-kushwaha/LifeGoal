"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildGoalContext = buildGoalContext;
exports.generateAINotification = generateAINotification;
function buildGoalContext(goals, globalInflation, globalReturn, todayIso) {
    const today = new Date(todayIso);
    if (goals.length === 0) {
        return "No goals configured yet.";
    }
    const goalBlocks = [];
    let totalRequiredSip = 0;
    const accounts = new Set();
    for (const goal of goals) {
        const inflationPct = goal.inflationRate ?? globalInflation;
        const returnPct = goal.expectedReturn ?? globalReturn;
        const inflation = inflationPct / 100;
        const returnRate = returnPct / 100;
        const start = goal.startDate ? new Date(goal.startDate) : today;
        const target = goal.targetDate ? new Date(goal.targetDate) : today;
        const years = Math.max(0, (target.getTime() - start.getTime()) / (365.25 * 24 * 3600 * 1000));
        const adjustedTarget = (goal.targetCost ?? 0) * Math.pow(1 + inflation, years);
        const remainingMonths = Math.max(0, (target.getFullYear() - today.getFullYear()) * 12 + (target.getMonth() - today.getMonth()) + 1);
        const currentSavings = goal.currentSavings ?? 0;
        const projected = remainingMonths <= 0
            ? currentSavings
            : currentSavings * Math.pow(1 + returnRate, remainingMonths / 12);
        const progress = adjustedTarget > 0 ? Math.min(100, (projected / adjustedTarget) * 100) : 100;
        const gap = Math.max(0, adjustedTarget - projected);
        const requiredSip = calculateRequiredSip(adjustedTarget, currentSavings, returnRate, remainingMonths);
        totalRequiredSip += requiredSip;
        const totalMonths = Math.max(1, (target.getFullYear() - start.getFullYear()) * 12 + (target.getMonth() - start.getMonth()));
        const elapsedMonths = Math.max(0, (today.getFullYear() - start.getFullYear()) * 12 + (today.getMonth() - start.getMonth()));
        const expectedProgress = elapsedMonths / totalMonths;
        const actualProgress = progress / 100;
        let health = "on track";
        if (gap <= 0) {
            health = "fully funded";
        }
        else if (actualProgress < expectedProgress * 0.8) {
            health = "behind schedule";
        }
        else if (actualProgress < expectedProgress) {
            health = "needs attention";
        }
        if (goal.account)
            accounts.add(goal.account);
        goalBlocks.push([
            `Goal ID: ${goal.id ?? "unknown"}`,
            `Name: ${goal.name ?? "Unnamed"}`,
            `Family member (account): ${goal.account ?? "Unknown"}`,
            `Timeline: ${formatDate(start)} → ${formatDate(target)} (${remainingMonths} months left)`,
            `Target cost today: ₹${formatInr(goal.targetCost ?? 0)}`,
            `Inflation-adjusted target: ₹${formatInr(adjustedTarget)} (inflation ${inflationPct}%)`,
            `Current savings: ₹${formatInr(currentSavings)}`,
            `Projected at target date: ₹${formatInr(projected)} (return ${returnPct}%)`,
            `Funding gap: ₹${formatInr(gap)}`,
            `Progress: ${progress.toFixed(1)}%`,
            `Required monthly SIP: ₹${formatInr(requiredSip)}`,
            `Health: ${health}`,
        ].join("\n"));
    }
    const header = [
        "=== Family goal portfolio ===",
        `Goals: ${goals.length}`,
        `Family members with goals: ${[...accounts].join(", ") || "none"}`,
        `Total required monthly SIP: ₹${formatInr(totalRequiredSip)}`,
        `Reference date: ${formatDate(today)}`,
        "",
        "=== Individual goals ===",
    ].join("\n");
    return `${header}\n\n${goalBlocks.join("\n\n")}`;
}
function calculateRequiredSip(adjustedTarget, currentSavings, monthlyReturnRate, remainingMonths) {
    if (remainingMonths <= 0)
        return 0;
    const annualRate = monthlyReturnRate;
    const projectedWithoutSip = currentSavings * Math.pow(1 + annualRate, remainingMonths / 12);
    const needed = adjustedTarget - projectedWithoutSip;
    if (needed <= 0)
        return 0;
    const r = annualRate / 12;
    if (r === 0)
        return needed / remainingMonths;
    return (needed * r) / (Math.pow(1 + r, remainingMonths) - 1);
}
function formatInr(amount) {
    return Math.round(amount).toLocaleString("en-IN");
}
function formatDate(date) {
    return date.toISOString().slice(0, 10);
}
async function generateAINotification(params) {
    const recentSummary = params.recentNotifications.length === 0
        ? "None"
        : params.recentNotifications
            .map((n, i) => `${i + 1}. Title: ${n.title}\n   Action: ${n.suggestedAction}\n   Body: ${n.body}`)
            .join("\n");
    const systemPrompt = `You are a financial planning assistant for LifeGoal AI — an Indian family SIP goal tracker.

Each family has multiple goals. Every goal has this structure:
- Goal ID, name, family member (account)
- Timeline (start → target date, months remaining)
- Target cost today, inflation-adjusted target, inflation %
- Current savings, projected value at target date, return %
- Funding gap, progress %, required monthly SIP, health status

Your job: analyze the portfolio data below and suggest ONE specific next action grounded in their actual numbers.

Rules:
1. Reference real goal names, family member accounts, ₹ amounts, SIP figures, progress %, or months remaining from the data.
2. Prioritize goals that are "behind schedule" or "needs attention", or deadlines within 12 months.
3. If event trigger relates to a specific goal, focus on that goal first.
4. Suggest concrete app actions: update current savings, increase monthly SIP, review inflation/return assumptions, rebalance across family members, or top up a specific goal.
5. Do NOT give generic advice like "save more" without citing their goal data.
6. Do NOT repeat suggestions from recent notifications.
7. Set relatedGoalId to the exact Goal ID from the data, or null if portfolio-wide.

Respond ONLY with valid JSON (no markdown):
{"title":"short title","body":"2-3 sentences citing specific goals and numbers","suggestedAction":"one concrete action with goal name and amount if applicable","relatedGoalId":"goal id or null"}`;
    const userPrompt = `Trigger: ${params.trigger}
Event: ${params.eventName ?? "none"}
Related goal ID (if event): ${params.relatedGoalId ?? "none"}

${params.goalContext}

Recent notifications (do not repeat these):
${recentSummary}`;
    const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
        method: "POST",
        headers: {
            Authorization: `Bearer ${params.apiKey}`,
            "Content-Type": "application/json",
            "HTTP-Referer": "https://lifegoal.app",
            "X-Title": "LifeGoal AI",
        },
        body: JSON.stringify({
            model: "google/gemini-2.5-flash",
            messages: [
                { role: "system", content: systemPrompt },
                { role: "user", content: userPrompt },
            ],
            temperature: 0.7,
            max_tokens: 500,
        }),
    });
    if (!response.ok) {
        const text = await response.text();
        throw new Error(`OpenRouter error ${response.status}: ${text}`);
    }
    const data = (await response.json());
    const content = data.choices?.[0]?.message?.content?.trim() ?? "";
    try {
        const jsonMatch = content.match(/\{[\s\S]*\}/);
        const parsed = JSON.parse(jsonMatch?.[0] ?? content);
        const goalId = parsed.relatedGoalId && parsed.relatedGoalId !== "null"
            ? parsed.relatedGoalId
            : undefined;
        return {
            title: parsed.title || "Financial check-in",
            body: parsed.body || "Review your goals and savings progress.",
            suggestedAction: parsed.suggestedAction || "Open the dashboard and update current savings.",
            relatedGoalId: goalId,
        };
    }
    catch {
        return {
            title: "Financial check-in",
            body: content.slice(0, 300) || "Review your goals today.",
            suggestedAction: "Open the dashboard and review goal progress.",
        };
    }
}
//# sourceMappingURL=ai.js.map