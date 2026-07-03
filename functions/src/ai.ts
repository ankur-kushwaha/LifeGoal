interface GoalData {
  id?: string;
  name?: string;
  account?: string;
  targetCost?: number;
  startDate?: string;
  targetDate?: string;
  currentSavings?: number;
  expectedReturn?: number;
  inflationRate?: number;
}

interface RecentNotification {
  title: string;
  body: string;
  suggestedAction: string;
  relatedGoalId?: string;
}

interface AIResult {
  title: string;
  body: string;
  suggestedAction: string;
  relatedGoalId?: string;
  suggestionType?: string;
  suggestedNewGoalName?: string;
  suggestedNewGoalTargetCost?: number;
  suggestedNewGoalMonths?: number;
  suggestedNewGoalAccount?: string;
}

export function buildGoalContext(
  goals: GoalData[],
  globalInflation: number,
  globalReturn: number,
  todayIso: string,
): string {
  const today = new Date(todayIso);
  if (goals.length === 0) {
    return "No goals configured yet.";
  }

  const goalBlocks: string[] = [];
  let totalRequiredSip = 0;
  const accounts = new Set<string>();

  for (const goal of goals) {
    const inflationPct = goal.inflationRate ?? globalInflation;
    const returnPct = goal.expectedReturn ?? globalReturn;
    const inflation = inflationPct / 100;
    const returnRate = returnPct / 100;
    const start = goal.startDate ? new Date(goal.startDate) : today;
    const target = goal.targetDate ? new Date(goal.targetDate) : today;
    const years = Math.max(0, (target.getTime() - start.getTime()) / (365.25 * 24 * 3600 * 1000));
    const adjustedTarget = (goal.targetCost ?? 0) * Math.pow(1 + inflation, years);
    const remainingMonths = Math.max(
      0,
      (target.getFullYear() - today.getFullYear()) * 12 + (target.getMonth() - today.getMonth()) + 1,
    );
    const currentSavings = goal.currentSavings ?? 0;
    const projected =
      remainingMonths <= 0
        ? currentSavings
        : currentSavings * Math.pow(1 + returnRate, remainingMonths / 12);
    const progress = adjustedTarget > 0 ? Math.min(100, (projected / adjustedTarget) * 100) : 100;
    const gap = Math.max(0, adjustedTarget - projected);
    const requiredSip = calculateRequiredSip(
      adjustedTarget,
      currentSavings,
      returnRate,
      remainingMonths,
    );
    totalRequiredSip += requiredSip;

    const totalMonths = Math.max(
      1,
      (target.getFullYear() - start.getFullYear()) * 12 + (target.getMonth() - start.getMonth()),
    );
    const elapsedMonths = Math.max(
      0,
      (today.getFullYear() - start.getFullYear()) * 12 + (today.getMonth() - start.getMonth()),
    );
    const expectedProgress = elapsedMonths / totalMonths;
    const actualProgress = progress / 100;
    let health = "on track";
    if (gap <= 0) {
      health = "fully funded";
    } else if (actualProgress < expectedProgress * 0.8) {
      health = "behind schedule";
    } else if (actualProgress < expectedProgress) {
      health = "needs attention";
    }

    if (goal.account) accounts.add(goal.account);

    goalBlocks.push(
      [
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
      ].join("\n"),
    );
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

function calculateRequiredSip(
  adjustedTarget: number,
  currentSavings: number,
  monthlyReturnRate: number,
  remainingMonths: number,
): number {
  if (remainingMonths <= 0) return 0;

  const annualRate = monthlyReturnRate;
  const projectedWithoutSip =
    currentSavings * Math.pow(1 + annualRate, remainingMonths / 12);
  const needed = adjustedTarget - projectedWithoutSip;
  if (needed <= 0) return 0;

  const r = annualRate / 12;
  if (r === 0) return needed / remainingMonths;
  return (needed * r) / (Math.pow(1 + r, remainingMonths) - 1);
}

function formatInr(amount: number): string {
  return Math.round(amount).toLocaleString("en-IN");
}

function formatDate(date: Date): string {
  return date.toISOString().slice(0, 10);
}

interface FamilyProfileData {
  monthlyHouseholdIncome?: number;
  monthlyHouseholdExpenses?: number;
  emergencyFundMonths?: number;
  housingStatus?: string;
  hasHealthInsurance?: boolean;
  hasLifeInsurance?: boolean;
  dependents?: Array<{
    name?: string;
    relationship?: string;
    dateOfBirth?: string;
  }>;
  loans?: Array<{
    type?: string;
    emi?: number;
    remainingMonths?: number;
    outstandingAmount?: number;
  }>;
}

interface MemberProfileData {
  dateOfBirth?: string;
  monthlyIncome?: number;
  monthlyExpenses?: number;
  employmentType?: string;
  riskAppetite?: string;
  retirementAge?: number;
}

function housingLabel(status?: string): string {
  switch (status) {
    case "own":
      return "Own home";
    case "planning_to_buy":
      return "Planning to buy";
    default:
      return "Renting";
  }
}

function loanTypeLabel(type?: string): string {
  switch (type) {
    case "home":
      return "Home loan";
    case "car":
      return "Car loan";
    case "education":
      return "Education loan";
    case "other":
      return "Other";
    default:
      return "Personal loan";
  }
}

function relationshipLabel(rel?: string): string {
  switch (rel) {
    case "parent":
      return "Parent";
    case "spouse":
      return "Spouse";
    case "other":
      return "Other";
    default:
      return "Child";
  }
}

function ageFromDob(dob?: string): number | null {
  if (!dob) return null;
  const birth = new Date(dob);
  if (Number.isNaN(birth.getTime())) return null;
  const now = new Date();
  let age = now.getFullYear() - birth.getFullYear();
  const monthDiff = now.getMonth() - birth.getMonth();
  if (monthDiff < 0 || (monthDiff === 0 && now.getDate() < birth.getDate())) {
    age--;
  }
  return age;
}

export function buildFamilyProfileContext(
  familyProfile?: FamilyProfileData,
  members?: Array<{ name: string; profile?: MemberProfileData }>,
): string {
  if (!familyProfile && (!members || members.length === 0)) {
    return "Family profile not filled in yet.";
  }

  const fp = familyProfile ?? {};
  const lines: string[] = ["=== Family financial profile ==="];

  if (fp.monthlyHouseholdIncome != null) {
    lines.push(`Household income: ₹${formatInr(fp.monthlyHouseholdIncome)}`);
  }
  if (fp.monthlyHouseholdExpenses != null) {
    lines.push(`Household expenses: ₹${formatInr(fp.monthlyHouseholdExpenses)}`);
  }

  const totalEmi = (fp.loans ?? []).reduce((sum, loan) => sum + (loan.emi ?? 0), 0);
  if (totalEmi > 0) {
    lines.push(`Total loan EMI: ₹${formatInr(totalEmi)}`);
  }

  if (fp.monthlyHouseholdIncome != null && fp.monthlyHouseholdExpenses != null) {
    const surplus = fp.monthlyHouseholdIncome - fp.monthlyHouseholdExpenses - totalEmi;
    lines.push(`Estimated monthly surplus for goals: ₹${formatInr(surplus)}`);
  }

  const emergencyMonths = fp.emergencyFundMonths ?? 6;
  if (fp.monthlyHouseholdExpenses != null) {
    lines.push(
      `Emergency fund target (${emergencyMonths} months): ₹${formatInr(fp.monthlyHouseholdExpenses * emergencyMonths)}`,
    );
  }

  lines.push(`Housing: ${housingLabel(fp.housingStatus)}`);
  lines.push(`Health insurance: ${fp.hasHealthInsurance ? "yes" : "no"}`);
  lines.push(`Life insurance: ${fp.hasLifeInsurance ? "yes" : "no"}`);

  if (fp.dependents && fp.dependents.length > 0) {
    lines.push("\nDependents:");
    for (const dep of fp.dependents) {
      const age = ageFromDob(dep.dateOfBirth);
      lines.push(
        `- ${dep.name ?? "Unknown"} (${relationshipLabel(dep.relationship)}${age != null ? `, age ${age}` : ""})`,
      );
    }
  }

  if (fp.loans && fp.loans.length > 0) {
    lines.push("\nLoans:");
    for (const loan of fp.loans) {
      lines.push(
        `- ${loanTypeLabel(loan.type)}: EMI ₹${formatInr(loan.emi ?? 0)}, ${loan.remainingMonths ?? 0} months left` +
          (loan.outstandingAmount != null ? `, outstanding ₹${formatInr(loan.outstandingAmount)}` : ""),
      );
    }
  }

  if (members && members.length > 0) {
    lines.push("\nMember profiles:");
    for (const member of members) {
      const p = member.profile ?? {};
      const parts = [member.name];
      const age = ageFromDob(p.dateOfBirth);
      if (age != null) parts.push(`age ${age}`);
      if (p.monthlyIncome != null) parts.push(`income ₹${formatInr(p.monthlyIncome)}`);
      if (p.monthlyExpenses != null) parts.push(`expenses ₹${formatInr(p.monthlyExpenses)}`);
      if (p.employmentType) parts.push(p.employmentType);
      if (p.riskAppetite) parts.push(`risk: ${p.riskAppetite}`);
      if (p.retirementAge) parts.push(`retire at ${p.retirementAge}`);
      lines.push(`- ${parts.join(", ")}`);
    }
  }

  const hasFamilyData =
    fp.monthlyHouseholdIncome != null ||
    fp.monthlyHouseholdExpenses != null ||
    (fp.dependents?.length ?? 0) > 0 ||
    (fp.loans?.length ?? 0) > 0;
  const hasMemberData = members?.some((m) => {
    const p = m.profile ?? {};
    return p.dateOfBirth != null || p.monthlyIncome != null || p.monthlyExpenses != null;
  });

  if (!hasFamilyData && !hasMemberData) {
    return "Family profile not filled in yet.";
  }

  return lines.join("\n");
}

export async function generateAINotification(params: {
  apiKey: string;
  goalContext: string;
  profileContext?: string;
  recentNotifications: RecentNotification[];
  trigger: string;
  eventName?: string;
  relatedGoalId?: string;
}): Promise<AIResult> {
  const recentGoalIds = params.recentNotifications
    .map((n) => n.relatedGoalId)
    .filter((id): id is string => Boolean(id));
  const blockedGoals =
    recentGoalIds.length > 0 ? recentGoalIds.join(", ") : "none";

  const recentSummary =
    params.recentNotifications.length === 0
      ? "None"
      : params.recentNotifications
          .map(
            (n, i) =>
              `${i + 1}. Goal ID: ${n.relatedGoalId ?? "portfolio-wide"}\n   Title: ${n.title}\n   Action: ${n.suggestedAction}\n   Body: ${n.body}`,
          )
          .join("\n");

  const systemPrompt = `You are a financial planning assistant for LifeGoal AI — an Indian family SIP goal tracker.

Each family has multiple goals. Every goal has this structure:
- Goal ID, name, family member (account)
- Timeline (start → target date, months remaining)
- Target cost today, inflation-adjusted target, inflation %
- Current savings, projected value at target date, return %
- Funding gap, progress %, required monthly SIP, health status

Your job: analyze the portfolio and suggest ONE specific next step. This can be:
A) An action on an existing goal (update savings, increase SIP, review assumptions)
B) A NEW goal to add that is missing from their portfolio (emergency fund, retirement, child education, health corpus, home down payment, insurance buffer)
C) A portfolio-wide review (rebalance SIP across members, total SIP vs capacity)

Common goals Indian families often need but may be missing:
- Emergency fund (3–6 months expenses)
- Retirement corpus
- Child education / marriage
- Health / medical corpus
- Home purchase down payment
- Vacation / lifestyle goals

If all existing goals are on track, suggest a NEW goal to add with a concrete name, target amount, timeline, and family member.

Use the family financial profile (income, expenses, dependents, loans, insurance, member ages) to:
- Check if emergency fund goal is missing when expenses are known
- Suggest child education goals when dependents with ages are listed
- Factor loan EMIs and monthly surplus when recommending SIP amounts
- Flag missing life/health insurance when not covered
- Align new goal timelines with dependent ages (e.g. education in ~15 years for a 3-year-old)

Rules:
1. Reference real goal names, family member accounts, ₹ amounts, SIP figures, progress %, or months remaining from the data.
2. Prioritize goals that are "behind schedule" or "needs attention", or deadlines within 12 months.
3. If event trigger relates to a specific goal, focus on that goal first.
4. For existing goals: suggest update savings, increase SIP, review inflation/return, or top up.
5. For missing goals: use suggestionType "add_new_goal" and fill suggestedNewGoal* fields with realistic Indian amounts.
6. Do NOT give generic advice without citing their data.
7. Do NOT repeat suggestions from recent notifications.
8. Do NOT suggest goals whose Goal ID is in the blocked list — pick a different goal or suggest a new goal to add.
9. Set relatedGoalId to an existing Goal ID, or null for new/portfolio-wide suggestions.

Respond ONLY with valid JSON (no markdown):
{"title":"short title","body":"2-3 sentences","suggestedAction":"concrete action","suggestionType":"action_on_goal|add_new_goal|portfolio_review","relatedGoalId":"goal id or null","suggestedNewGoalName":"name or null","suggestedNewGoalTargetCost":number or null,"suggestedNewGoalMonths":number or null,"suggestedNewGoalAccount":"family member name or null"}`;

  const userPrompt = `Trigger: ${params.trigger}
Event: ${params.eventName ?? "none"}
Related goal ID (if event): ${params.relatedGoalId ?? "none"}

${params.goalContext}

${params.profileContext ?? "Family profile not filled in yet."}

Blocked goal IDs (already suggested recently — do not use): ${blockedGoals}

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

  const data = (await response.json()) as {
    choices?: Array<{ message?: { content?: string } }>;
  };
  const content = data.choices?.[0]?.message?.content?.trim() ?? "";

  try {
    const jsonMatch = content.match(/\{[\s\S]*\}/);
    const parsed = JSON.parse(jsonMatch?.[0] ?? content) as AIResult;
    const goalId =
      parsed.relatedGoalId && parsed.relatedGoalId !== "null"
        ? parsed.relatedGoalId
        : undefined;
    return {
      title: parsed.title || "Financial check-in",
      body: parsed.body || "Review your goals and savings progress.",
      suggestedAction: parsed.suggestedAction || "Open the dashboard and update current savings.",
      relatedGoalId: goalId,
      suggestionType: parsed.suggestionType,
      suggestedNewGoalName: parsed.suggestedNewGoalName,
      suggestedNewGoalTargetCost: parsed.suggestedNewGoalTargetCost,
      suggestedNewGoalMonths: parsed.suggestedNewGoalMonths,
      suggestedNewGoalAccount: parsed.suggestedNewGoalAccount,
    };
  } catch {
    return {
      title: "Financial check-in",
      body: content.slice(0, 300) || "Review your goals today.",
      suggestedAction: "Open the dashboard and review goal progress.",
    };
  }
}
