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
  double _simulatedInflationOverride = 0.0;
  double _simulatedReturnOverride = 0.0;
  bool _isSimulatorInitialized = false;

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

    // Initialize simulation overrides
    if (!_isSimulatorInitialized) {
      _simulatedReturnOverride = goal.expectedReturn ?? provider.globalReturn;
      _simulatedInflationOverride = goal.inflationRate ?? provider.globalInflation;
      _isSimulatorInitialized = true;
    }

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

    // Simulator Math
    final simReturnRate = _simulatedReturnOverride / 100.0;
    final simInflationRate = _simulatedInflationOverride / 100.0;
    
    // Recalculate target with simulated inflation
    final years = goal.getYearsFromStartToTarget();
    final simInflationTarget = targetCost * pow(1 + simInflationRate, years);
    
    // Recalculate savings with simulated returns
    final simProjectedSavings = currentSavings * pow(1 + simReturnRate, remainingMonths / 12.0);
    final simRemainingNeeded = (simInflationTarget - simProjectedSavings).clamp(0.0, double.infinity);
    
    // Recalculate required SIP
    double simRequiredSip = 0.0;
    if (remainingMonths > 0 && simRemainingNeeded > 0) {
      final monthlySimReturn = simReturnRate / 12.0;
      simRequiredSip = monthlySimReturn > 0
          ? simRemainingNeeded * monthlySimReturn / (pow(1 + monthlySimReturn, remainingMonths) - 1)
          : simRemainingNeeded / remainingMonths;
    }

    final simProgressPct = (simProjectedSavings / simInflationTarget * 100).clamp(0.0, 100.0);

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
            ),
            const SizedBox(height: 24),

            // Interactive Simulator Section
            Row(
              children: [
                Icon(Icons.psychology, color: kMoneyGreen, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Scenario Simulator (AI Engine)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Simulate how changes in inflation or expected return rates affect your required monthly SIP contribution.',
              style: TextStyle(color: Colors.black38, fontSize: 12),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kCardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kMoneyGreen.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SIMULATOR OUTPUTS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('SIMULATED REQUIRED SIP', style: TextStyle(color: Colors.black38, fontSize: 9, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              _currencyFormatter.format(simRequiredSip),
                              style: const TextStyle(color: kMoneyGreen, fontSize: 20, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('SIMULATED TARGET COST', style: TextStyle(color: Colors.black38, fontSize: 9, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              _currencyFormatter.format(simInflationTarget),
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Progress Bar for simulation
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: simProgressPct / 100.0,
                            minHeight: 8,
                            backgroundColor: Colors.black12,
                            valueColor: const AlwaysStoppedAnimation<Color>(kMoneyGreen),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${simProgressPct.toStringAsFixed(0)}%', style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Divider(color: Colors.black.withOpacity(0.06)),
                  const SizedBox(height: 12),

                  // CONTROLS 1: Simulated Inflation Rate
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Simulated Inflation: ${_simulatedInflationOverride.toStringAsFixed(1)}%',
                        style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _simulatedInflationOverride = goal.inflationRate ?? provider.globalInflation;
                          });
                        },
                        child: const Text('Reset', style: TextStyle(color: kMoneyGreen, fontSize: 12)),
                      )
                    ],
                  ),
                  Slider(
                    value: _simulatedInflationOverride,
                    min: 0,
                    max: 20,
                    divisions: 40,
                    activeColor: kMoneyGreen,
                    inactiveColor: Colors.black12,
                    onChanged: (val) {
                      setState(() {
                        _simulatedInflationOverride = val;
                      });
                    },
                  ),

                  // CONTROLS 2: Rate of return Slider override
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Simulated Rate of Return: ${_simulatedReturnOverride.toStringAsFixed(1)}%',
                        style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _simulatedReturnOverride = goal.expectedReturn ?? provider.globalReturn;
                          });
                        },
                        child: const Text('Reset', style: TextStyle(color: kMoneyGreen, fontSize: 12)),
                      )
                    ],
                  ),
                  Slider(
                    value: _simulatedReturnOverride,
                    min: 0,
                    max: 30,
                    divisions: 60,
                    activeColor: kMoneyGreen,
                    inactiveColor: Colors.black12,
                    onChanged: (val) {
                      setState(() {
                        _simulatedReturnOverride = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // Scenario analysis recommendations
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kScaffoldBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getSimulationRecommendation(requiredSip, simRequiredSip, _simulatedInflationOverride, _simulatedReturnOverride),
                      style: const TextStyle(color: Colors.black54, fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
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
  }) {
    final progressPct = inflationTarget > 0
        ? (goal.currentSavings / inflationTarget * 100).clamp(0.0, 100.0)
        : 100.0;
    final sipRequired = goal.getRequiredSIP(today, globalInflation, globalReturn);
    final barColor = progressPct >= 100 ? const Color(0xFF10B981) : healthColor;
    final chartSeries = goal.getGrowthChartSeries(today, globalReturn);
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
            '$recordedLabel, and projected growth at ${returnRatePct.toStringAsFixed(1)}% p.a. with no new SIP.',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
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

  // AI-like recommendation text generator based on simulation parameters
  String _getSimulationRecommendation(
    double originalRequiredSip,
    double simulatedRequiredSip,
    double simulatedInflation,
    double simulatedReturn,
  ) {
    final diff = simulatedRequiredSip - originalRequiredSip;
    if (diff.round() == 0) {
      return "💡 Adjust the sliders to see how changes in inflation and return rates affect your required monthly SIP.";
    } else if (diff < 0) {
      return "🎉 Positive scenario! Under this simulation, your required monthly installment decreases by ${_currencyFormatter.format(-diff)} due to lower inflation / higher return assumptions.";
    } else {
      return "⚠ Warning: Under this simulation, you will need to invest an additional ${_currencyFormatter.format(diff)} per month to achieve your goal on time.";
    }
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
