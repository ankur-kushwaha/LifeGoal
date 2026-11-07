export interface GoalData {
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

export interface FamilyProfileData {
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
    lenderName?: string;
  }>;
}

export interface MemberProfileData {
  dateOfBirth?: string;
  monthlyIncome?: number;
  monthlyExpenses?: number;
  employmentType?: string;
  riskAppetite?: string;
  retirementAge?: number;
}

export interface RecentNotification {
  title: string;
  body: string;
  suggestedAction: string;
  relatedGoalId?: string;
}

export interface NotificationResult {
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

interface Candidate {
  priority: number;
  title: string;
  body: string;
  suggestedAction: string;
  relatedGoalId?: string;
  suggestionType: string;
  suggestedNewGoalName?: string;
  suggestedNewGoalTargetCost?: number;
  suggestedNewGoalMonths?: number;
  suggestedNewGoalAccount?: string;
}

export function formatInr(amount: number): string {
  return Math.round(amount).toLocaleString("en-IN");
}

export function formatDate(date: Date): string {
  const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  return `${months[date.getMonth()]} ${date.getFullYear()}`;
}

export function calculateRequiredSip(
  adjustedTarget: number,
  currentSavings: number,
  annualReturnRate: number,
  remainingMonths: number,
): number {
  if (remainingMonths <= 0) return 0;

  const projectedWithoutSip =
    currentSavings * Math.pow(1 + annualReturnRate, remainingMonths / 12);
  const needed = adjustedTarget - projectedWithoutSip;
  if (needed <= 0) return 0;

  const r = annualReturnRate / 12;
  if (r === 0) return needed / remainingMonths;
  return (needed * r) / (Math.pow(1 + r, remainingMonths) - 1);
}

/**
 * Pure mathematical computation engine for financial notifications.
 * Evaluates goals, target dates, monthly salary/income, EMIs, expenses,
 * surplus vs required SIP, loan payoffs, and deadlines.
 */
export function computeFinancialNotification(params: {
  goals: GoalData[];
  familyProfile?: FamilyProfileData;
  members?: Array<{ name: string; profile?: MemberProfileData }>;
  recentNotifications: RecentNotification[];
  trigger: string;
  eventName?: string;
  relatedGoalId?: string;
  globalInflation: number;
  globalReturn: number;
  todayIso: string;
}): NotificationResult {
  const today = new Date(params.todayIso);
  const goals = params.goals;
  const fp = params.familyProfile ?? {};
  const members = params.members ?? [];
  const recent = params.recentNotifications;

  if (goals.length === 0) {
    return {
      title: "Set up your first financial goal",
      body: "Track your future milestones with inflation-adjusted targets and monthly SIP math. Add your first goal to get started.",
      suggestedAction: "Tap the + button to create a goal with target date and cost.",
      suggestionType: "add_new_goal",
    };
  }

  // 1. Calculate monthly salary / income
  let monthlyIncome: number | undefined = fp.monthlyHouseholdIncome;
  if (monthlyIncome == null || monthlyIncome <= 0) {
    const memberIncomeSum = members.reduce(
      (sum, m) => sum + (m.profile?.monthlyIncome ?? 0),
      0,
    );
    if (memberIncomeSum > 0) monthlyIncome = memberIncomeSum;
  }

  const monthlyExpenses = fp.monthlyHouseholdExpenses;
  const totalLoanEmi = (fp.loans ?? []).reduce(
    (sum, l) => sum + (l.emi ?? 0),
    0,
  );

  let monthlySurplus: number | undefined;
  if (monthlyIncome != null && monthlyExpenses != null) {
    monthlySurplus = monthlyIncome - monthlyExpenses - totalLoanEmi;
  }

  // 2. Compute individual goal metrics
  interface ProcessedGoal {
    goal: GoalData;
    targetDate: Date;
    startDate: Date;
    remainingMonths: number;
    years: number;
    adjustedTarget: number;
    projected: number;
    gap: number;
    progress: number;
    requiredSip: number;
    health: "fullyFunded" | "behindSchedule" | "needsAttention" | "onTrack";
  }

  const processedGoals: ProcessedGoal[] = [];
  let totalRequiredSip = 0;

  for (const g of goals) {
    const inflationPct = g.inflationRate ?? params.globalInflation;
    const returnPct = g.expectedReturn ?? params.globalReturn;
    const inflation = inflationPct / 100;
    const returnRate = returnPct / 100;

    const start = g.startDate ? new Date(g.startDate) : today;
    const target = g.targetDate ? new Date(g.targetDate) : today;

    const years = Math.max(0, (target.getTime() - start.getTime()) / (365.25 * 24 * 3600 * 1000));
    const adjustedTarget = (g.targetCost ?? 0) * Math.pow(1 + inflation, years);

    const remainingMonths = Math.max(
      0,
      (target.getFullYear() - today.getFullYear()) * 12 + (target.getMonth() - today.getMonth()) + 1,
    );

    const currentSavings = g.currentSavings ?? 0;
    const projected =
      remainingMonths <= 0
        ? currentSavings
        : currentSavings * Math.pow(1 + returnRate, remainingMonths / 12);

    const gap = Math.max(0, adjustedTarget - projected);
    const requiredSip = calculateRequiredSip(adjustedTarget, currentSavings, returnRate, remainingMonths);
    totalRequiredSip += requiredSip;

    const progress = adjustedTarget > 0 ? Math.min(100, (projected / adjustedTarget) * 100) : 100;

    // Discipline ratio
    const totalMonths = Math.max(
      1,
      (target.getFullYear() - start.getFullYear()) * 12 + (target.getMonth() - start.getMonth()),
    );
    const elapsedMonths = Math.max(
      0,
      (today.getFullYear() - start.getFullYear()) * 12 + (today.getMonth() - start.getMonth()),
    );
    const r = returnRate / 12;
    const scheduledSIP = r > 0
      ? (adjustedTarget * r) / (Math.pow(1 + r, totalMonths) - 1)
      : adjustedTarget / totalMonths;
    const clampedElapsed = Math.min(elapsedMonths, totalMonths);
    const scheduledAccumulated = r > 0
      ? (scheduledSIP * (Math.pow(1 + r, clampedElapsed) - 1)) / r
      : scheduledSIP * clampedElapsed;
    const disciplineRatio = scheduledAccumulated > 0
      ? currentSavings / scheduledAccumulated
      : 1.0;

    let health: "fullyFunded" | "behindSchedule" | "needsAttention" | "onTrack" = "onTrack";
    if (gap <= 0 || progress >= 99) {
      health = "fullyFunded";
    } else if (disciplineRatio < 0.8) {
      health = "behindSchedule";
    } else if (disciplineRatio < 1.0) {
      health = "needsAttention";
    }

    processedGoals.push({
      goal: g,
      targetDate: target,
      startDate: start,
      remainingMonths,
      years,
      adjustedTarget,
      projected,
      gap,
      progress,
      requiredSip,
      health,
    });
  }

  const candidates: Candidate[] = [];

  // ==========================================
  // CANDIDATE 1: SIP vs Monthly Surplus Deficit
  // ==========================================
  if (monthlySurplus != null && totalRequiredSip > monthlySurplus && monthlySurplus > 0) {
    const deficit = totalRequiredSip - monthlySurplus;
    candidates.push({
      priority: 150,
      title: `Required SIP exceeds surplus by ₹${formatInr(deficit)}`,
      body: `Your goals require ₹${formatInr(totalRequiredSip)}/mo in total SIP. But after monthly salary/income (₹${formatInr(monthlyIncome!)}), expenses (₹${formatInr(monthlyExpenses!)}), and EMIs (₹${formatInr(totalLoanEmi)}), your surplus is ₹${formatInr(monthlySurplus)}/mo.`,
      suggestedAction: `Consider extending goal target dates or reviewing expenses to bridge the ₹${formatInr(deficit)}/mo gap.`,
      suggestionType: "portfolio_review",
    });
  }

  // ==========================================
  // CANDIDATE 2: High Debt-to-Income (EMI Ratio)
  // ==========================================
  if (monthlyIncome != null && monthlyIncome > 0 && totalLoanEmi > 0) {
    const emiRatio = totalLoanEmi / monthlyIncome;
    if (emiRatio >= 0.40) {
      candidates.push({
        priority: 140,
        title: `High EMI load: ${Math.round(emiRatio * 100)}% of monthly salary`,
        body: `Your family's loan EMIs total ₹${formatInr(totalLoanEmi)}/mo against ₹${formatInr(monthlyIncome)} monthly income. Recommended limit is under 40% to protect savings growth.`,
        suggestedAction: `Focus surplus cash on prepaying high-interest loans to free up monthly cash flow for your goals.`,
        suggestionType: "portfolio_review",
      });
    }
  }

  // ==========================================
  // CANDIDATE 3: Approaching Loan Payoff Milestone
  // ==========================================
  const maturingLoans = (fp.loans ?? []).filter(
    (l) => (l.remainingMonths ?? 0) > 0 && (l.remainingMonths ?? 0) <= 6 && (l.emi ?? 0) > 0,
  );
  if (maturingLoans.length > 0) {
    const loan = maturingLoans[0];
    candidates.push({
      priority: 135,
      title: `${loan.type ?? "Loan"} EMI ending in ${loan.remainingMonths} months!`,
      body: `Your monthly EMI of ₹${formatInr(loan.emi!)} will be paid off in ${loan.remainingMonths} months. That will free up ₹${formatInr(loan.emi!)} every month for investments.`,
      suggestedAction: `Plan to redirect the ₹${formatInr(loan.emi!)}/mo freed cash flow directly into your priority goals.`,
      suggestionType: "portfolio_review",
    });
  }

  // ==========================================
  // CANDIDATE 4: Individual Goals Behind Schedule
  // ==========================================
  for (const pg of processedGoals) {
    if (pg.health === "behindSchedule") {
      candidates.push({
        priority: 120,
        title: `${pg.goal.name ?? "Goal"} needs attention`,
        body: `Target date is ${formatDate(pg.targetDate)} (${pg.remainingMonths} months left). Current savings ₹${formatInr(pg.goal.currentSavings ?? 0)} vs inflation-adjusted target ₹${formatInr(pg.adjustedTarget)}. Required SIP is ₹${formatInr(pg.requiredSip)}/month.`,
        suggestedAction: `Increase monthly SIP to ₹${formatInr(pg.requiredSip)} or allocate extra savings to close the gap.`,
        relatedGoalId: pg.goal.id,
        suggestionType: "action_on_goal",
      });
    }
  }

  // ==========================================
  // CANDIDATE 5: Approaching Goal Deadline (< 12 months)
  // ==========================================
  for (const pg of processedGoals) {
    if (pg.remainingMonths > 0 && pg.remainingMonths <= 12 && pg.gap > 0) {
      candidates.push({
        priority: 110,
        title: `${pg.goal.name ?? "Goal"} target date in ${pg.remainingMonths} months`,
        body: `Maturing on ${formatDate(pg.targetDate)}. Progress is ${pg.progress.toFixed(0)}% with a remaining gap of ₹${formatInr(pg.gap)}. Required monthly contribution is ₹${formatInr(pg.requiredSip)}/mo.`,
        suggestedAction: `Review final balance and consider a one-time top-up to achieve ${pg.goal.name} on time.`,
        relatedGoalId: pg.goal.id,
        suggestionType: "action_on_goal",
      });
    }
  }

  // ==========================================
  // CANDIDATE 6: Unallocated Monthly Surplus
  // ==========================================
  if (monthlySurplus != null && monthlySurplus > totalRequiredSip + 3000) {
    const unallocated = monthlySurplus - totalRequiredSip;
    candidates.push({
      priority: 100,
      title: `₹${formatInr(unallocated)}/mo unallocated monthly surplus`,
      body: `After household expenses (₹${formatInr(monthlyExpenses!)}), loan EMIs (₹${formatInr(totalLoanEmi)}), and current goal SIPs (₹${formatInr(totalRequiredSip)}), you have ₹${formatInr(unallocated)}/mo surplus left.`,
      suggestedAction: `Boost SIP allocations on long-term wealth goals to compound wealth faster.`,
      suggestionType: "portfolio_review",
    });
  }

  // ==========================================
  // CANDIDATE 7: Emergency Fund Check
  // ==========================================
  if (monthlyExpenses != null && monthlyExpenses > 0) {
    const emMonths = fp.emergencyFundMonths ?? 6;
    const emTarget = monthlyExpenses * emMonths;
    const hasEmergencyGoal = goals.some((g) =>
      (g.name ?? "").toLowerCase().includes("emergency"),
    );

    if (!hasEmergencyGoal) {
      candidates.push({
        priority: 95,
        title: `Build an Emergency Fund (₹${formatInr(emTarget)})`,
        body: `Based on monthly household expenses of ₹${formatInr(monthlyExpenses)}, a ${emMonths}-month emergency buffer requires ₹${formatInr(emTarget)} kept in liquid savings or FD.`,
        suggestedAction: `Create a dedicated Emergency Fund goal to protect your family against unexpected expenses.`,
        suggestionType: "add_new_goal",
        suggestedNewGoalName: "Emergency Fund",
        suggestedNewGoalTargetCost: emTarget,
        suggestedNewGoalMonths: 12,
      });
    }
  }

  // ==========================================
  // CANDIDATE 8: Goals Fully Funded
  // ==========================================
  for (const pg of processedGoals) {
    if (pg.health === "fullyFunded" && (pg.goal.currentSavings ?? 0) > 0) {
      candidates.push({
        priority: 85,
        title: `${pg.goal.name ?? "Goal"} is fully funded!`,
        body: `Current savings of ₹${formatInr(pg.goal.currentSavings ?? 0)} are projected to reach ₹${formatInr(pg.projected)} by ${formatDate(pg.targetDate)}, covering the ₹${formatInr(pg.adjustedTarget)} target.`,
        suggestedAction: `Review asset allocation as the target date approaches to preserve accumulated capital.`,
        relatedGoalId: pg.goal.id,
        suggestionType: "action_on_goal",
      });
    }
  }

  // ==========================================
  // CANDIDATE 9: Weekly Goal & SIP Summary
  // ==========================================
  const sortedByTarget = [...processedGoals].sort(
    (a, b) => a.targetDate.getTime() - b.targetDate.getTime(),
  );
  const earliest = sortedByTarget[0];
  const latest = sortedByTarget[sortedByTarget.length - 1];

  let summaryBody = `Tracking ${goals.length} active goals with a total required monthly SIP of ₹${formatInr(totalRequiredSip)}. Timelines span from ${formatDate(earliest.targetDate)} to ${formatDate(latest.targetDate)}.`;
  if (monthlySurplus != null) {
    summaryBody += ` Estimated monthly cash surplus: ₹${formatInr(monthlySurplus)}.`;
  }

  candidates.push({
    priority: 50,
    title: "Weekly financial goal check-in",
    body: summaryBody,
    suggestedAction: "Open each goal to update latest savings and keep calculations accurate.",
    suggestionType: "portfolio_review",
  });

  // If specific goal was requested via event
  if (params.relatedGoalId) {
    for (const c of candidates) {
      if (c.relatedGoalId === params.relatedGoalId) {
        c.priority += 200;
      }
    }
  }

  // Sort by priority descending
  candidates.sort((a, b) => b.priority - a.priority);

  // Deduplicate against recent notifications
  const recentTitles = new Set(recent.map((n) => n.title.toLowerCase().trim()));
  const recentGoalIds = new Set(
    recent.map((n) => n.relatedGoalId).filter((id): id is string => Boolean(id)),
  );

  for (const c of candidates) {
    const titleKey = c.title.toLowerCase().trim();
    if (recentTitles.has(titleKey)) continue;
    if (c.relatedGoalId && recentGoalIds.has(c.relatedGoalId) && candidates.length > 2) {
      continue;
    }
    return {
      title: c.title,
      body: c.body,
      suggestedAction: c.suggestedAction,
      relatedGoalId: c.relatedGoalId ?? params.relatedGoalId,
      suggestionType: c.suggestionType,
      suggestedNewGoalName: c.suggestedNewGoalName,
      suggestedNewGoalTargetCost: c.suggestedNewGoalTargetCost,
      suggestedNewGoalMonths: c.suggestedNewGoalMonths,
      suggestedNewGoalAccount: c.suggestedNewGoalAccount,
    };
  }

  // Fallback to top candidate
  const fallback = candidates[0];
  return {
    title: fallback.title,
    body: fallback.body,
    suggestedAction: fallback.suggestedAction,
    relatedGoalId: fallback.relatedGoalId ?? params.relatedGoalId,
    suggestionType: fallback.suggestionType,
    suggestedNewGoalName: fallback.suggestedNewGoalName,
    suggestedNewGoalTargetCost: fallback.suggestedNewGoalTargetCost,
    suggestedNewGoalMonths: fallback.suggestedNewGoalMonths,
    suggestedNewGoalAccount: fallback.suggestedNewGoalAccount,
  };
}
