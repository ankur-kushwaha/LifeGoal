import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../models/goal_model.dart';
import '../providers/goal_provider.dart';
import '../widgets/growth_chart.dart';
import 'goal_form_screen.dart';

class GoalDetailScreen extends StatefulWidget {
  final String goalId;

  const GoalDetailScreen({super.key, required this.goalId});

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  GoalTimeframe _selectedTimeframe = GoalTimeframe.all;
  bool _sortNewestFirst = true;
  bool _filterToChartTimeframe = true;

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GoalProvider>(context);
    final theme = Theme.of(context);

    // Fetch the target goal
    final goalIndex = provider.goals.indexWhere((g) => g.id == widget.goalId);
    if (goalIndex == -1) {
      return Scaffold(
        backgroundColor: kScaffoldBg,
        appBar: AppBar(backgroundColor: kCardBg),
        body: const Center(child: Text('Goal not found', style: TextStyle(color: Colors.black87))),
      );
    }

    final goal = provider.goals[goalIndex];

    // Read calculated financial parameters
    final double inflation = goal.getEffectiveInflationRate(provider.globalInflation);
    final double globalReturnRate = goal.getEffectiveReturnRate(provider.globalReturn);
    final double targetCost = goal.targetCost;
    final double inflationTarget = goal.getInflationAdjustedTarget(provider.globalInflation);
    final double currentSavings = goal.currentSavings;
    final double projectedSavings = goal.getProjectedSavings(provider.today, provider.globalReturn);
    final double requiredSip = goal.getRequiredSIP(provider.today, provider.globalInflation, provider.globalReturn);
    final double requiredLumpSum = goal.getRequiredLumpSumToday(provider.today, provider.globalInflation, provider.globalReturn);
    final int remainingMonths = goal.getRemainingMonths(provider.today);
    final double progress = goal.getPercentDone(provider.today, provider.globalInflation, provider.globalReturn);
    final health = goal.getHealth(provider.today, provider.globalInflation, provider.globalReturn);


    // Goal Health Styling
    final Color healthColor;
    final String healthText;
    switch (health) {
      case GoalHealth.onTrack:
        healthColor = const Color(0xFF10B981);
        healthText = 'On Track';
        break;
      case GoalHealth.needsAttention:
        healthColor = const Color(0xFFF59E0B);
        healthText = 'Attention';
        break;
      case GoalHealth.behindSchedule:
        healthColor = const Color(0xFFEF4444);
        healthText = 'Behind';
        break;
    }

    final balanceNeeded = (inflationTarget - currentSavings).clamp(0.0, double.infinity);
    final savedProgress = inflationTarget > 0
        ? (currentSavings / inflationTarget).clamp(0.0, 1.0)
        : 0.0;
    final memberLabel = provider.resolveMemberLabel(goal.account);
    final memberColors = [
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
      const Color(0xFF8B5CF6),
    ];
    final memberIndex = provider.familyMembers.indexWhere((m) => m.matchesAccount(goal.account));
    final memberColor = memberIndex != -1
        ? memberColors[memberIndex % memberColors.length]
        : const Color(0xFF64748B);

    final chartSeries = goal.getGrowthChartSeries(
      provider.today,
      provider.globalReturn,
      timeframe: _selectedTimeframe,
    );

    return Scaffold(
      backgroundColor: kScaffoldBg,
      appBar: AppBar(
        backgroundColor: kScaffoldBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGoalDetailHeader(
              goal: goal,
              memberLabel: memberLabel,
              memberColor: memberColor,
              remainingMonths: remainingMonths,
              healthColor: healthColor,
              healthText: healthText,
              progressPercent: progress,
              onEdit: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GoalFormScreen(goal: goal)),
                );
              },
              onDelete: () => _confirmDelete(context, provider, goal),
            ),
            const SizedBox(height: 16),
            _buildProgressToTargetCard(
              healthColor: healthColor,
              savedProgress: savedProgress,
              currentSavings: currentSavings,
              inflationTarget: inflationTarget,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDetailStatCard(
                    'Balance Needed',
                    _currencyFormatter.format(balanceNeeded),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildDetailStatCard(
                    'Monthly SIP',
                    _currencyFormatter.format(requiredSip),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildDetailStatCard(
                    'Invest Today',
                    _currencyFormatter.format(requiredLumpSum),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kCardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMiniMetric(
                    goal.knowsTargetAmount ? "Est. Today's Cost" : 'Original Goal',
                    _currencyFormatter.format(targetCost),
                  ),
                  _buildMiniMetric(
                    goal.knowsTargetAmount ? 'Your Target' : 'Inflation-Adj Target',
                    _currencyFormatter.format(inflationTarget),
                  ),
                  _buildMiniMetric('Projected Savings', _currencyFormatter.format(projectedSavings)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildGrowthTimelineCard(
              goal: goal,
              today: provider.today,
              globalReturn: provider.globalReturn,
              globalInflation: provider.globalInflation,
              inflationTarget: inflationTarget,
              remainingMonths: remainingMonths,
              inflationPct: inflation * 100,
              returnRatePct: globalReturnRate * 100,
              healthColor: healthColor,
              chartSeries: chartSeries,
            ),
            const SizedBox(height: 24),

            _buildInvestmentChangesCard(
              context: context,
              goal: goal,
              provider: provider,
              chartSeries: chartSeries,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildGrowthTimelineCard({
    required GoalModel goal,
    required DateTime today,
    required double globalReturn,
    required double globalInflation,
    required double inflationTarget,
    required int remainingMonths,
    required double inflationPct,
    required double returnRatePct,
    required Color healthColor,
    required List<GrowthChartPoint> chartSeries,
  }) {
    final progressPct = inflationTarget > 0
        ? (goal.currentSavings / inflationTarget * 100).clamp(0.0, 100.0)
        : 100.0;
    final sipRequired = goal.getRequiredSIP(today, globalInflation, globalReturn);
    final barColor = progressPct >= 100 ? const Color(0xFF10B981) : healthColor;
    final recordedCount = chartSeries.where((p) => !p.isProjected).length;
    final recordedLabel = recordedCount > 1
        ? 'From goal start to today'
        : 'From goal start';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Growth Timeline',
            style: TextStyle(color: kMoneyGreen, fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            "Snapshot today, projected growth, and the plan's key dates",
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTimelineChip('Started', DateFormat('dd-MMM-yyyy').format(goal.startDate)),
              _buildTimelineChip('Target Date', DateFormat('dd-MMM-yyyy').format(goal.targetDate)),
              _buildTimelineChip('Time Left', _formatMonthsLeft(remainingMonths)),
              _buildTimelineChip('Inflation', '${inflationPct.toStringAsFixed(1)}%'),
              _buildTimelineChip('Return', '${returnRatePct.toStringAsFixed(1)}%'),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TODAY',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _currencyFormatter.format(goal.currentSavings),
                            style: const TextStyle(
                              color: kMoneyGreen,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () {
                            final provider = Provider.of<GoalProvider>(context, listen: false);
                            _showQuickUpdateSavingsDialog(context, goal, provider);
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: kMoneyGreen.withOpacity(0.85),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      goal.knowsTargetAmount
                          ? 'YOUR TARGET'
                          : 'TARGET (INFLATION-ADJUSTED)',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currencyFormatter.format(inflationTarget),
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progressPct / 100.0,
              minHeight: 10,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${progressPct.toStringAsFixed(0)}% funded',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: sipRequired > 0
                  ? barColor.withOpacity(0.1)
                  : const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              sipRequired > 0
                  ? 'SIP required to close the gap: ${_currencyFormatter.format(sipRequired)} / month for $remainingMonths month${remainingMonths == 1 ? '' : 's'}'
                  : remainingMonths <= 0
                      ? 'This goal has reached its target date.'
                      : 'No monthly SIP needed — savings are on track to fully fund this goal.',
              style: TextStyle(
                color: sipRequired > 0 ? barColor : const Color(0xFF065F46),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 520;
              final String chartSubtitle;
              if (_selectedTimeframe == GoalTimeframe.all) {
                chartSubtitle = '$recordedLabel, and projected growth at ${returnRatePct.toStringAsFixed(1)}% p.a. with no new SIP.';
              } else {
                final startAmount = chartSeries.isNotEmpty ? chartSeries.first.amount : 0.0;
                final endAmount = chartSeries.isNotEmpty ? chartSeries.last.amount : 0.0;
                final diff = endAmount - startAmount;
                final diffStr = _currencyFormatter.format(diff.abs());
                final periodLabel = _selectedTimeframe == GoalTimeframe.oneMonth
                    ? 'past 1 month'
                    : _selectedTimeframe == GoalTimeframe.threeMonths
                        ? 'past 3 months'
                        : _selectedTimeframe == GoalTimeframe.sixMonths
                            ? 'past 6 months'
                            : 'past 1 year';
                if (diff > 0.5) {
                  final pct = startAmount > 0 ? ' (+${(diff / startAmount * 100).toStringAsFixed(1)}%)' : '';
                  chartSubtitle = 'Recorded savings grew by +$diffStr$pct over $periodLabel.';
                } else if (diff < -0.5) {
                  final pct = startAmount > 0 ? ' (-${(diff.abs() / startAmount * 100).toStringAsFixed(1)}%)' : '';
                  chartSubtitle = 'Recorded savings changed by -$diffStr$pct over $periodLabel.';
                } else {
                  chartSubtitle = 'Recorded savings balance remained at ${_currencyFormatter.format(endAmount)} over $periodLabel.';
                }
              }

              final timeframeSelector = _buildTimeframeSelector();

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Growth chart',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            chartSubtitle,
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    timeframeSelector,
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Growth chart',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      chartSubtitle,
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    timeframeSelector,
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 12),
          GrowthChart(
            points: chartSeries,
            targetAmount: inflationTarget,
            today: today,
            currencyFormatter: _currencyFormatter,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: GoalTimeframe.values.map((tf) {
          final isSelected = _selectedTimeframe == tf;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (_selectedTimeframe != tf) {
                  setState(() {
                    _selectedTimeframe = tf;
                  });
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  tf.label,
                  style: TextStyle(
                    color: isSelected ? kMoneyGreen : const Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimelineChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${label.toUpperCase()}  ',
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMonthsLeft(int remainingMonths) {
    if (remainingMonths == 0) return 'Achieved!';
    if (remainingMonths > 24) {
      final years = remainingMonths / 12.0;
      return '${years.toStringAsFixed(years >= 10 ? 0 : 1)} yr left';
    }
    return '$remainingMonths mo left';
  }

  IconData _goalIcon(String goalName) {
    final name = goalName.toLowerCase();
    if (name.contains('bali') || name.contains('travel') || name.contains('trip') || name.contains('vacation') || name.contains('flight')) {
      return Icons.flight_takeoff_rounded;
    }
    if (name.contains('home') || name.contains('house') || name.contains('flat') || name.contains('land') || name.contains('loan')) {
      return Icons.home_rounded;
    }
    if (name.contains('emergency') || name.contains('medical') || name.contains('hospital') || name.contains('health') || name.contains('security')) {
      return Icons.shield_rounded;
    }
    if (name.contains('education') || name.contains('school') || name.contains('college') || name.contains('university') || name.contains('study') || name.contains('nursery')) {
      return Icons.school_rounded;
    }
    if (name.contains('wedding') || name.contains('shadi') || name.contains('marriage')) {
      return Icons.favorite_rounded;
    }
    if (name.contains('car') || name.contains('bike') || name.contains('vehicle')) {
      return Icons.directions_car_rounded;
    }
    if (name.contains('retirement') || name.contains('pension')) {
      return Icons.elderly_rounded;
    }
    return Icons.star_rounded;
  }

  Widget _buildGoalDetailHeader({
    required GoalModel goal,
    required String memberLabel,
    required Color memberColor,
    required int remainingMonths,
    required Color healthColor,
    required String healthText,
    required double progressPercent,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      value: (progressPercent / 100).clamp(0.0, 1.0),
                      strokeWidth: 3.5,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(healthColor),
                    ),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: healthColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_goalIcon(goal.name), color: healthColor, size: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.name,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: memberColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          memberLabel.toUpperCase(),
                          style: TextStyle(
                            color: memberColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      Text(
                        _formatMonthsLeft(remainingMonths),
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '•  $healthText',
                        style: TextStyle(
                          color: healthColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onEdit,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F172A),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            ),
            const SizedBox(width: 6),
            OutlinedButton(
              onPressed: onDelete,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: BorderSide(color: const Color(0xFFEF4444).withOpacity(0.35)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressToTargetCard({
    required Color healthColor,
    required double savedProgress,
    required double currentSavings,
    required double inflationTarget,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PROGRESS TO TARGET',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: savedProgress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(healthColor),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${_currencyFormatter.format(currentSavings)} ',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const TextSpan(
                              text: 'saved',
                              style: TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      'of ${_currencyFormatter.format(inflationTarget)}',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    value: savedProgress,
                    strokeWidth: 5.5,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(healthColor),
                  ),
                ),
                Text(
                  '${(savedProgress * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.black45, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildInvestmentChangesCard({
    required BuildContext context,
    required GoalModel goal,
    required GoalProvider provider,
    required List<GrowthChartPoint> chartSeries,
  }) {
    // Retrieve all recorded points across all time for accurate delta calculations
    final allActualPoints = goal
        .getGrowthChartSeries(
          provider.today,
          provider.globalReturn,
          timeframe: GoalTimeframe.all,
        )
        .where((p) => !p.isProjected)
        .toList();

    final List<_InvestmentEntry> allEntries = [];
    for (int i = 0; i < allActualPoints.length; i++) {
      final point = allActualPoints[i];
      final double? prevAmount = i > 0 ? allActualPoints[i - 1].amount : null;
      final double diff = prevAmount != null ? (point.amount - prevAmount) : 0.0;
      final double? pct = (prevAmount != null && prevAmount > 0)
          ? (diff / prevAmount * 100)
          : null;
      final isStart = GoalModel.isSameCalendarDay(point.date, goal.startDate);
      final isToday = GoalModel.isSameCalendarDay(point.date, provider.today);
      final snapIdx = goal.savingsHistory.indexWhere(
        (s) => GoalModel.isSameCalendarDay(s.date, point.date),
      );
      final snap = snapIdx >= 0 ? goal.savingsHistory[snapIdx] : null;

      allEntries.add(
        _InvestmentEntry(
          date: point.date,
          amount: point.amount,
          previousAmount: prevAmount,
          diff: diff,
          percentChange: pct,
          isStartDate: isStart,
          isToday: isToday,
          snapshot: snap,
        ),
      );
    }

    final chartRecorded = chartSeries.where((p) => !p.isProjected).toList();
    final List<_InvestmentEntry> displayEntries;
    if (_filterToChartTimeframe && _selectedTimeframe != GoalTimeframe.all) {
      displayEntries = allEntries.where((e) {
        return chartRecorded.any((cp) => GoalModel.isSameCalendarDay(cp.date, e.date));
      }).toList();
    } else {
      displayEntries = List<_InvestmentEntry>.from(allEntries);
    }

    if (_sortNewestFirst) {
      displayEntries.sort((a, b) => b.date.compareTo(a.date));
    } else {
      displayEntries.sort((a, b) => a.date.compareTo(b.date));
    }

    // Calculate net growth for the visible period
    double? netGrowth;
    double? netGrowthPct;
    if (displayEntries.isNotEmpty) {
      final chronological = List<_InvestmentEntry>.from(displayEntries)
        ..sort((a, b) => a.date.compareTo(b.date));
      final firstVal = chronological.first.amount;
      final lastVal = chronological.last.amount;
      netGrowth = lastVal - firstVal;
      if (firstVal > 0) {
        netGrowthPct = (netGrowth / firstVal) * 100;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.table_chart_rounded,
                          color: kMoneyGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Investment Changes',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedTimeframe != GoalTimeframe.all && _filterToChartTimeframe
                          ? 'Showing ${displayEntries.length} recorded change${displayEntries.length == 1 ? '' : 's'} in chart timeframe (${_selectedTimeframe.label})'
                          : 'Showing all ${displayEntries.length} recorded balance changes from goal start to today',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _showRecordInvestmentDialog(context, goal, provider),
                icon: const Icon(Icons.add_rounded, size: 16, color: kMoneyGreen),
                label: const Text(
                  'Record Change',
                  style: TextStyle(
                    color: kMoneyGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: kMoneyGreen.withOpacity(0.06),
                  side: BorderSide(color: kMoneyGreen.withOpacity(0.35)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Filters and Sort Control Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_selectedTimeframe != GoalTimeframe.all)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFilterToggleTab(
                        label: 'Chart (${_selectedTimeframe.label})',
                        isSelected: _filterToChartTimeframe,
                        onTap: () {
                          if (!_filterToChartTimeframe) {
                            setState(() => _filterToChartTimeframe = true);
                          }
                        },
                      ),
                      _buildFilterToggleTab(
                        label: 'All (${allEntries.length})',
                        isSelected: !_filterToChartTimeframe,
                        onTap: () {
                          if (_filterToChartTimeframe) {
                            setState(() => _filterToChartTimeframe = false);
                          }
                        },
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${displayEntries.length} record${displayEntries.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              // Sort button
              InkWell(
                onTap: () => setState(() => _sortNewestFirst = !_sortNewestFirst),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _sortNewestFirst
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        size: 13,
                        color: const Color(0xFF475569),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _sortNewestFirst ? 'Newest first' : 'Oldest first',
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Main Table / Card Content
          if (displayEntries.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.history_rounded,
                    color: Color(0xFF94A3B8),
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No recorded investment changes in this timeframe.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  if (_filterToChartTimeframe && _selectedTimeframe != GoalTimeframe.all)
                    TextButton(
                      onPressed: () => setState(() => _filterToChartTimeframe = false),
                      child: const Text('View All Records', style: TextStyle(color: kMoneyGreen)),
                    ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 520;
                if (isWide) {
                  return _buildWideInvestmentTable(
                    context: context,
                    goal: goal,
                    provider: provider,
                    entries: displayEntries,
                  );
                } else {
                  return _buildNarrowInvestmentList(
                    context: context,
                    goal: goal,
                    provider: provider,
                    entries: displayEntries,
                  );
                }
              },
            ),

          // Period Summary Footer
          if (displayEntries.length > 1 && netGrowth != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Period Net Growth',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        netGrowth >= 0
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 16,
                        color: netGrowth >= 0
                            ? const Color(0xFF059669)
                            : const Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${netGrowth >= 0 ? '+' : '-'}${_currencyFormatter.format(netGrowth.abs())}${netGrowthPct != null ? ' (${netGrowth >= 0 ? '+' : ''}${netGrowthPct.toStringAsFixed(1)}%)' : ''}',
                        style: TextStyle(
                          color: netGrowth >= 0
                              ? const Color(0xFF059669)
                              : const Color(0xFFDC2626),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterToggleTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? kMoneyGreen : const Color(0xFF64748B),
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWideInvestmentTable({
    required BuildContext context,
    required GoalModel goal,
    required GoalProvider provider,
    required List<_InvestmentEntry> entries,
  }) {
    const headerStyle = TextStyle(
      color: Color(0xFF94A3B8),
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('DATE', style: headerStyle),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'RECORDED BALANCE',
                    textAlign: TextAlign.right,
                    style: headerStyle,
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    'INVESTMENT CHANGE',
                    textAlign: TextAlign.right,
                    style: headerStyle,
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    'ACTIONS',
                    textAlign: TextAlign.center,
                    style: headerStyle,
                  ),
                ),
              ],
            ),
          ),

          // Table Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFF1F5F9),
            ),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    // Date & Badges
                    Expanded(
                      flex: 3,
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          Text(
                            DateFormat('dd-MMM-yyyy').format(entry.date),
                            style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (entry.isToday)
                            _buildMiniBadge('Today', const Color(0xFFECFDF5), const Color(0xFF059669))
                          else if (entry.isStartDate)
                            _buildMiniBadge('Start', const Color(0xFFF1F5F9), const Color(0xFF64748B)),
                        ],
                      ),
                    ),

                    // Recorded Balance
                    Expanded(
                      flex: 3,
                      child: Text(
                        _currencyFormatter.format(entry.amount),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                    // Investment Change
                    Expanded(
                      flex: 4,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _buildChangePill(entry),
                      ),
                    ),

                    // Actions
                    SizedBox(
                      width: 80,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          InkWell(
                            onTap: () => _showEditInvestmentDialog(context, goal, provider, entry),
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
                            ),
                          ),
                          if (entry.snapshot != null)
                            InkWell(
                              onTap: () => _showDeleteInvestmentDialog(context, goal, provider, entry),
                              borderRadius: BorderRadius.circular(6),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                              ),
                            )
                          else
                            const SizedBox(width: 28),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNarrowInvestmentList({
    required BuildContext context,
    required GoalModel goal,
    required GoalProvider provider,
    required List<_InvestmentEntry> entries,
  }) {
    return Column(
      children: entries.map((entry) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top line: Date + Badges on left, Actions on right
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      Text(
                        DateFormat('dd-MMM-yyyy').format(entry.date),
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (entry.isToday)
                        _buildMiniBadge('Today', const Color(0xFFECFDF5), const Color(0xFF059669))
                      else if (entry.isStartDate)
                        _buildMiniBadge('Start', const Color(0xFFF1F5F9), const Color(0xFF64748B)),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => _showEditInvestmentDialog(context, goal, provider, entry),
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
                        ),
                      ),
                      if (entry.snapshot != null)
                        InkWell(
                          onTap: () => _showDeleteInvestmentDialog(context, goal, provider, entry),
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Bottom line: Balance on left, Change on right
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recorded Balance',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currencyFormatter.format(entry.amount),
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  _buildChangePill(entry),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMiniBadge(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildChangePill(_InvestmentEntry entry) {
    if (entry.isStartDate && (entry.previousAmount == null || entry.diff == 0)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          entry.amount > 0 ? 'Starting balance' : 'Goal started (₹0)',
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (entry.previousAmount == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'Initial: ${_currencyFormatter.format(entry.amount)}',
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (entry.diff > 0) {
      final pctStr = entry.percentChange != null
          ? ' (+${entry.percentChange!.toStringAsFixed(1)}%)'
          : '';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_upward_rounded, size: 12, color: Color(0xFF059669)),
            const SizedBox(width: 3),
            Text(
              '+${_currencyFormatter.format(entry.diff)}$pctStr',
              style: const TextStyle(
                color: Color(0xFF059669),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    if (entry.diff < 0) {
      final pctStr = entry.percentChange != null
          ? ' (${entry.percentChange!.toStringAsFixed(1)}%)'
          : '';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_downward_rounded, size: 12, color: Color(0xFFDC2626)),
            const SizedBox(width: 3),
            Text(
              '-${_currencyFormatter.format(entry.diff.abs())}$pctStr',
              style: const TextStyle(
                color: Color(0xFFDC2626),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return const Text(
      '—',
      style: TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  void _showRecordInvestmentDialog(
    BuildContext context,
    GoalModel goal,
    GoalProvider provider,
  ) {
    DateTime selectedDate = DateTime.now();
    final controller = TextEditingController(text: goal.currentSavings.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: kCardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: kMoneyGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_circle_outline_rounded, color: kMoneyGreen, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Record Investment Change',
                  style: TextStyle(color: Colors.black87, fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Record a savings balance for "${goal.name}".',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: goal.startDate,
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) {
                    setDialogState(() {
                      selectedDate = picked;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: kScaffoldBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 16, color: kMoneyGreen),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('dd-MMM-yyyy').format(selectedDate),
                            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),
                      const Text('Change Date', style: TextStyle(color: kMoneyGreen, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Savings Balance (₹)',
                  prefixText: '₹ ',
                  labelStyle: const TextStyle(color: Colors.black54),
                  fillColor: kScaffoldBg,
                  filled: true,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.black12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: kMoneyGreen, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kMoneyGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save Record'),
              onPressed: () async {
                final val = double.tryParse(controller.text.trim());
                if (val != null && val >= 0) {
                  try {
                    await provider.updateGoalSavings(goal, val, onDate: selectedDate);
                    if (!context.mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Recorded balance of ${_currencyFormatter.format(val)} for ${DateFormat('dd-MMM-yyyy').format(selectedDate)}.',
                        ),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not save record: $e')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid positive number')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditInvestmentDialog(
    BuildContext context,
    GoalModel goal,
    GoalProvider provider,
    _InvestmentEntry entry,
  ) {
    DateTime selectedDate = entry.date;
    final controller = TextEditingController(text: entry.amount.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: kCardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: kMoneyGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_outlined, color: kMoneyGreen, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Edit Investment Record',
                  style: TextStyle(color: Colors.black87, fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Update recorded balance for "${goal.name}".',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: goal.startDate,
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) {
                    setDialogState(() {
                      selectedDate = picked;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: kScaffoldBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 16, color: kMoneyGreen),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('dd-MMM-yyyy').format(selectedDate),
                            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),
                      const Text('Change Date', style: TextStyle(color: kMoneyGreen, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Savings Balance (₹)',
                  prefixText: '₹ ',
                  labelStyle: const TextStyle(color: Colors.black54),
                  fillColor: kScaffoldBg,
                  filled: true,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.black12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: kMoneyGreen, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kMoneyGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Update'),
              onPressed: () async {
                final val = double.tryParse(controller.text.trim());
                if (val != null && val >= 0) {
                  try {
                    await provider.editGoalSavingsSnapshot(
                      goal,
                      oldDate: entry.date,
                      newDate: selectedDate,
                      newAmount: val,
                    );
                    if (!context.mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Updated balance to ${_currencyFormatter.format(val)} for ${DateFormat('dd-MMM-yyyy').format(selectedDate)}.',
                        ),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not update record: $e')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid positive number')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteInvestmentDialog(
    BuildContext context,
    GoalModel goal,
    GoalProvider provider,
    _InvestmentEntry entry,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Record', style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to remove the record of ${_currencyFormatter.format(entry.amount)} on ${DateFormat('dd-MMM-yyyy').format(entry.date)}?',
          style: const TextStyle(color: Colors.black87, fontSize: 14),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete'),
            onPressed: () async {
              try {
                await provider.deleteGoalSavingsSnapshot(goal, entry.date);
                if (!context.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Removed record for ${DateFormat('dd-MMM-yyyy').format(entry.date)}.',
                    ),
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not delete record: $e')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, GoalProvider provider, GoalModel goal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('Delete Goal', style: TextStyle(color: Colors.black87)),
        content: Text('Are you sure you want to delete "${goal.name}"?', style: const TextStyle(color: Colors.black87)),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
            onPressed: () {
              provider.deleteGoal(goal.id);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to dashboard
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Goal "${goal.name}" deleted successfully.')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showQuickUpdateSavingsDialog(BuildContext context, GoalModel goal, GoalProvider provider) {
    final controller = TextEditingController(text: goal.currentSavings.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('Update Current Savings', style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter savings balance for "${goal.name}" as of ${DateFormat('dd MMM yyyy').format(DateTime.now())}:',
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                labelText: 'Current Savings (₹)',
                labelStyle: const TextStyle(color: Colors.black54),
                fillColor: kScaffoldBg,
                filled: true,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.black12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: kMoneyGreen),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kMoneyGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save'),
            onPressed: () async {
              final val = double.tryParse(controller.text.trim());
              if (val != null && val >= 0) {
                final asOf = DateTime.now();
                try {
                  await provider.updateGoalSavings(goal, val);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Savings for "${goal.name}" saved for ${DateFormat('dd MMM yyyy').format(asOf)}.',
                      ),
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not save savings: $e')),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid positive number')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _InvestmentEntry {
  final DateTime date;
  final double amount;
  final double? previousAmount;
  final double diff;
  final double? percentChange;
  final bool isStartDate;
  final bool isToday;
  final SavingsSnapshot? snapshot;

  const _InvestmentEntry({
    required this.date,
    required this.amount,
    required this.previousAmount,
    required this.diff,
    required this.percentChange,
    required this.isStartDate,
    required this.isToday,
    this.snapshot,
  });
}
