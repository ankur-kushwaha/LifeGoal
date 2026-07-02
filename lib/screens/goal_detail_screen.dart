import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../models/goal_model.dart';
import '../providers/goal_provider.dart';
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
  int _timelineMonths = 0;
  bool _timelineInitialized = false;

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
    final double remainingNeeded = goal.getRemainingAmountNeeded(provider.today, provider.globalInflation, provider.globalReturn);
    final double requiredSip = goal.getRequiredSIP(provider.today, provider.globalInflation, provider.globalReturn);
    final int remainingMonths = goal.getRemainingMonths(provider.today);
    final double progress = goal.getPercentDone(provider.today, provider.globalInflation, provider.globalReturn);
    final health = goal.getHealth(provider.today, provider.globalInflation, provider.globalReturn);

    // Initialize simulation overrides
    if (!_isSimulatorInitialized) {
      _simulatedReturnOverride = goal.expectedReturn ?? provider.globalReturn;
      _simulatedInflationOverride = goal.inflationRate ?? provider.globalInflation;
      _isSimulatorInitialized = true;
    }

    if (!_timelineInitialized) {
      _timelineMonths = 0;
      _timelineInitialized = true;
    }
    _timelineMonths = _timelineMonths.clamp(0, remainingMonths);

    // Goal Health Styling
    Color healthColor;
    String healthText;
    IconData healthIcon;
    switch (health) {
      case GoalHealth.onTrack:
        healthColor = kMoneyGreen;
        healthText = 'On Track';
        healthIcon = Icons.check_circle_outline;
        break;
      case GoalHealth.needsAttention:
        healthColor = Colors.orangeAccent;
        healthText = 'Needs Attention';
        healthIcon = Icons.warning_amber_rounded;
        break;
      case GoalHealth.behindSchedule:
        healthColor = Colors.redAccent;
        healthText = 'Behind Schedule';
        healthIcon = Icons.error_outline;
        break;
    }

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
        backgroundColor: kCardBg,
        title: Text(goal.name, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.black54),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GoalFormScreen(goal: goal),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => _confirmDelete(context, provider, goal),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header stats block
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kCardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.08)),
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
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('REQUIRED INSTALLMENT TODAY', style: TextStyle(color: Colors.black45, fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(
                            _currencyFormatter.format(requiredSip),
                            style: const TextStyle(
                              color: kMoneyGreen,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: healthColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(healthIcon, color: healthColor, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              healthText,
                              style: TextStyle(color: healthColor, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Divider(color: Colors.black.withOpacity(0.06), height: 1),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMiniMetric('Original Goal', _currencyFormatter.format(targetCost)),
                      _buildMiniMetric('Inflation-Adj Target', _currencyFormatter.format(inflationTarget)),
                      _buildMiniMetric('Projected Savings', _currencyFormatter.format(projectedSavings)),
                    ],
                  ),
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
              returnRatePct: globalReturnRate * 100,
            ),
            const SizedBox(height: 24),

            // Timeline & Plan parameters
            const Text(
              'Timeline Details',
              style: TextStyle(color: kMoneyGreen, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kCardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withOpacity(0.08)),
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
                children: [
                  _buildTimelineRow('Goal Start Date', DateFormat('dd-MMM-yyyy').format(goal.startDate)),
                  Divider(color: Colors.black.withOpacity(0.06), height: 20),
                  _buildTimelineRow('Target Date', DateFormat('dd-MMM-yyyy').format(goal.targetDate)),
                  Divider(color: Colors.black.withOpacity(0.06), height: 20),
                  _buildTimelineRow('Remaining Investment Time', '$remainingMonths months (${(remainingMonths / 12).toStringAsFixed(1)} years)'),
                  Divider(color: Colors.black.withOpacity(0.06), height: 20),
                  _buildTimelineRow('Assumed Annual Inflation', '${(inflation * 100).toStringAsFixed(1)}%'),
                  Divider(color: Colors.black.withOpacity(0.06), height: 20),
                  _buildTimelineRow('Assumed Rate of Return', '${(globalReturnRate * 100).toStringAsFixed(1)}%'),
                ],
              ),
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
    required double returnRatePct,
  }) {
    if (remainingMonths <= 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
        ),
        child: const Text(
          'This goal has reached its target date. No further growth timeline applies.',
          style: TextStyle(color: Colors.black54, fontSize: 13),
        ),
      );
    }

    final projectedAtMonth = goal.getSavingsAfterMonths(today, globalReturn, _timelineMonths);
    final timelineDate = GoalModel.dateAfterMonths(today, _timelineMonths);
    final progressPct = inflationTarget > 0
        ? (projectedAtMonth / inflationTarget * 100).clamp(0.0, 100.0)
        : 100.0;
    final shortfall = (inflationTarget - projectedAtMonth).clamp(0.0, double.infinity);
    final sipRequired = _timelineMonths == 0
        ? goal.getRequiredSIP(today, globalInflation, globalReturn)
        : goal.getRequiredSIPAfterMonths(
            today,
            globalInflation,
            globalReturn,
            _timelineMonths,
          );
    final monthsLeft = remainingMonths - _timelineMonths;
    final isAtTarget = _timelineMonths >= remainingMonths;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Growth Timeline',
          style: TextStyle(color: kMoneyGreen, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 4),
        const Text(
          'See how your current savings grow over time with no additional investments.',
          style: TextStyle(color: Colors.black38, fontSize: 12),
        ),
        const SizedBox(height: 12),
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
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _timelineMonths == 0 ? 'TODAY' : 'PROJECTED SAVINGS',
                        style: const TextStyle(
                          color: Colors.black38,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currencyFormatter.format(projectedAtMonth),
                        style: const TextStyle(
                          color: kMoneyGreen,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'ON DATE',
                        style: TextStyle(
                          color: Colors.black38,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd MMM yyyy').format(timelineDate),
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progressPct / 100.0,
                        minHeight: 8,
                        backgroundColor: Colors.black12,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progressPct >= 100 ? kMoneyGreen : Colors.orangeAccent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${progressPct.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${progressPct.toStringAsFixed(0)}% of inflation-adjusted target (${_currencyFormatter.format(inflationTarget)})',
                style: const TextStyle(color: Colors.black45, fontSize: 11),
              ),
              if (isAtTarget && shortfall > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Shortfall of ${_currencyFormatter.format(shortfall)} even with no further investing.',
                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
                  ),
                )
              else if (isAtTarget && shortfall == 0)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Your current savings are projected to fully fund this goal.',
                    style: TextStyle(color: kMoneyGreen, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                )
              else if (monthsLeft > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    sipRequired > 0
                        ? 'SIP required to fill gap: ${_currencyFormatter.format(sipRequired)} / month for $monthsLeft month${monthsLeft == 1 ? '' : 's'}'
                        : 'No monthly SIP needed from this point — savings cover the inflated goal.',
                    style: TextStyle(
                      color: sipRequired > 0 ? Colors.orangeAccent : kMoneyGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Divider(color: Colors.black.withOpacity(0.06)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _timelineMonths == 0
                        ? 'Today'
                        : '${_timelineMonths} mo${_timelineMonths == 1 ? '' : 's'} from now',
                    style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${returnRatePct.toStringAsFixed(1)}% p.a. · no new SIP',
                    style: const TextStyle(color: Colors.black38, fontSize: 11),
                  ),
                ],
              ),
              Slider(
                value: _timelineMonths.toDouble(),
                min: 0,
                max: remainingMonths.toDouble(),
                divisions: remainingMonths > 1 ? remainingMonths : 1,
                activeColor: kMoneyGreen,
                inactiveColor: Colors.black12,
                label: DateFormat('MMM yyyy').format(timelineDate),
                onChanged: (val) => setState(() => _timelineMonths = val.round()),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('dd MMM yyyy').format(today),
                    style: const TextStyle(color: Colors.black38, fontSize: 10),
                  ),
                  Text(
                    DateFormat('dd MMM yyyy').format(goal.targetDate),
                    style: const TextStyle(color: Colors.black38, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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

  Widget _buildTimelineRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
        Text(value, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13)),
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
}
