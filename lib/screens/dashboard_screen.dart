import 'package:flutter/material.dart';
import '../constants.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/goal_model.dart';
import '../providers/goal_provider.dart';
import '../widgets/app_logo.dart';
import 'goal_detail_screen.dart';
import 'goal_form_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedAccount = 'All';
  bool _isSettingsExpanded = false;

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GoalProvider>(context);
    final theme = Theme.of(context);

    // Filter goals based on active family tab
    final filteredGoals = _selectedAccount == 'All'
        ? provider.goals
        : provider.goals.where((g) => g.account.trim().toLowerCase() == _selectedAccount.toLowerCase()).toList();

    // Dynamically fetch account list
    final familyMembers = ['All', ...provider.accounts];

    return Scaffold(
      backgroundColor: kScaffoldBg, // Premium Dark Slate
      appBar: AppBar(
        backgroundColor: kCardBg,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const AppLogo(size: 28, showBackground: false),
                const SizedBox(width: 8),
                Text(
                  'LifeGoal AI',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            Text(
              provider.isFirebaseMode ? 'Cloud Connected' : 'Local Offline Mode',
              style: TextStyle(
                fontSize: 10,
                color: provider.isFirebaseMode ? kMoneyGreen : Colors.amber[800],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isSettingsExpanded ? Icons.tune : Icons.tune_outlined,
              color: _isSettingsExpanded ? kMoneyGreen : Colors.black54,
            ),
            tooltip: 'Global Adjustments',
            onPressed: () {
              setState(() {
                _isSettingsExpanded = !_isSettingsExpanded;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.backup_outlined, color: Colors.black54),
            tooltip: 'Backup / Restore Data',
            onPressed: () => _showBackupRestoreDialog(context, provider),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle, color: kMoneyGreen),
            onSelected: (value) async {
              if (value == 'logout') {
                await provider.signOut();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                enabled: false,
                child: Text(
                  provider.isFirebaseMode ? 'Cloud Connected' : 'Local Demo Mode',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                ),
              ),
              if (provider.currentUserId != null)
                PopupMenuItem<String>(
                  enabled: false,
                  child: Text(
                    'ID: ${provider.currentUserId}',
                    style: const TextStyle(fontSize: 11, color: Colors.black38),
                  ),
                ),
              if (provider.isAuthenticated) ...[
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.redAccent, size: 20),
                      SizedBox(width: 8),
                      Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: kMoneyGreen))
          : RefreshIndicator(
              onRefresh: () async {
                // Shared preferences loads automatically, but we notify listeners just in case
                provider.notifyListeners();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  // Global Settings Drawer Section (Collapsible)
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: _buildGlobalSettingsCard(provider),
                    crossFadeState: _isSettingsExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 300),
                  ),

                  // Top Wealth Overview Dashboard
                  _buildFinancialSummaryGrid(provider),

                  // Family Filter Tab Bar
                  _buildFamilyTabBar(familyMembers),

                  // Goal Cards Title & Stats
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_selectedAccount == 'All' ? 'All' : "$_selectedAccount's"} Goals (${filteredGoals.length})',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Swipe card to edit/delete',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Goals List
                  if (filteredGoals.isEmpty)
                    _buildEmptyState(context)
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredGoals.length,
                      itemBuilder: (context, index) {
                        final goal = filteredGoals[index];
                        return _buildGoalCard(context, goal, provider);
                      },
                    ),
                  const SizedBox(height: 80), // Padding to clear FAB
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kMoneyGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, fontWeight: FontWeight.bold),
        label: const Text('Add Life Goal', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const GoalFormScreen(),
            ),
          );
        },
      ),
    );
  }

  // Widget: Empty State UI
  Widget _buildEmptyState(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, spreadRadius: 1, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          const Icon(Icons.hourglass_empty, color: Colors.black38, size: 64),
          const SizedBox(height: 16),
          Text(
            'No Goals Found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to add your first financial life goal.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  // Widget: Collapsible settings card
  Widget _buildGlobalSettingsCard(GoalProvider provider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kMoneyGreen.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: kMoneyGreen.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.settings, color: kMoneyGreen, size: 20),
              SizedBox(width: 8),
              Text(
                'Global Adjustments & Timeline',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Inflation Rate Slider
          Text(
            'Global Inflation Rate: ${provider.globalInflation.toStringAsFixed(1)}%',
            style: const TextStyle(color: Colors.black54, fontSize: 14),
          ),
          Slider(
            value: provider.globalInflation,
            min: 0,
            max: 20,
            divisions: 40,
            activeColor: kMoneyGreen,
            inactiveColor: Colors.black12,
            onChanged: (val) {
              provider.updateSettings(inflation: val);
            },
          ),
          // Expected Return Slider
          Text(
            'Expected Investment Return: ${provider.globalReturn.toStringAsFixed(1)}%',
            style: const TextStyle(color: Colors.black54, fontSize: 14),
          ),
          Slider(
            value: provider.globalReturn,
            min: 0,
            max: 30,
            divisions: 60,
            activeColor: kMoneyGreen,
            inactiveColor: Colors.black12,
            onChanged: (val) {
              provider.updateSettings(rateOfReturn: val);
            },
          ),
          const SizedBox(height: 8),
          // Reference Date editor
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reference "Today" Date:',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  Text(
                    DateFormat('dd-MMM-yyyy').format(provider.today),
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () => _pickReferenceDate(context, provider),
                icon: const Icon(Icons.calendar_month, color: kMoneyGreen, size: 16),
                label: const Text('Change Date', style: TextStyle(color: kMoneyGreen)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: kMoneyGreen),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  // Widget: Pick reference date dialog
  Future<void> _pickReferenceDate(BuildContext context, GoalProvider provider) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: provider.today,
      firstDate: DateTime(2020),
      lastDate: DateTime(2060),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: kMoneyGreen,
              onPrimary: Colors.black,
              surface: kCardBg,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      provider.updateSettings(referenceToday: picked);
    }
  }

  // Widget: Financial Summary Dashboard cards
  Widget _buildFinancialSummaryGrid(GoalProvider provider) {
    final double requiredSip = provider.totalRequiredSIP;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // ETMONEY Hero Card: Highlight Required Monthly Installation Today
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEDFDF9), Color(0xFFFFFFFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(
                  color: kMoneyGreen.withOpacity(0.06),
                  blurRadius: 15,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'MONTHLY INSTALLMENT FOR TODAY',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _currencyFormatter.format(requiredSip),
                            style: const TextStyle(
                              color: kMoneyGreen,
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Wheel of Wealth / Progress Circle
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: kScaffoldBg,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: provider.overallProgressPercentage / 100.0,
                            strokeWidth: 5,
                            backgroundColor: Colors.black12,
                            valueColor: const AlwaysStoppedAnimation<Color>(kMoneyGreen),
                          ),
                          Text(
                            '${provider.overallProgressPercentage.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: kMoneyGreen,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Divider(color: Colors.black.withOpacity(0.06), height: 1),
                const SizedBox(height: 18),
                
                // Details Grid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSummaryDetailColumn(
                      'TOTAL SAVINGS',
                      _currencyFormatter.format(provider.totalWealthInvested),
                      Colors.black87,
                    ),
                    _buildSummaryDetailColumn(
                      'REMAINING NEEDED',
                      _currencyFormatter.format(provider.totalRemainingInvestment),
                      Colors.black87,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryDetailColumn(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // Widget: Family Tab Filter
  Widget _buildFamilyTabBar(List<String> accounts) {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: accounts.length,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (context, index) {
          final acc = accounts[index];
          final isSelected = _selectedAccount.toLowerCase() == acc.toLowerCase();
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(
                acc,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.black87 : Colors.black87,
                ),
              ),
              selected: isSelected,
              selectedColor: kMoneyGreen,
              backgroundColor: kCardBg,
              side: BorderSide(
                color: isSelected ? kMoneyGreen : Colors.black.withOpacity(0.06),
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedAccount = acc;
                  });
                }
              },
            ),
          );
        },
      ),
    );
  }

  // Widget: Goal Card list item
  Widget _buildGoalCard(BuildContext context, GoalModel goal, GoalProvider provider) {
    final double target = goal.getInflationAdjustedTarget(provider.globalInflation);
    final double reqSip = goal.getRequiredSIP(provider.today, provider.globalInflation, provider.globalReturn);
    final int remainingMonths = goal.getRemainingMonths(provider.today);
    final health = goal.getHealth(provider.today, provider.globalInflation, provider.globalReturn);

    // Calculate actual current progress (not projected)
    final double progress = target > 0 
        ? (goal.currentSavings / target * 100.0).clamp(0.0, 100.0)
        : 100.0;

    Color healthColor;
    String healthText;
    IconData healthIcon;
    switch (health) {
      case GoalHealth.onTrack:
        healthColor = kMoneyGreen;
        healthText = 'On Track';
        healthIcon = Icons.check_circle;
        break;
      case GoalHealth.needsAttention:
        healthColor = Colors.orangeAccent;
        healthText = 'Needs Attention';
        healthIcon = Icons.warning_rounded;
        break;
      case GoalHealth.behindSchedule:
        healthColor = Colors.redAccent;
        healthText = 'Behind';
        healthIcon = Icons.error;
        break;
    }

    return Dismissible(
      key: Key(goal.id),
      direction: DismissDirection.horizontal,
      background: Container(
        color: Colors.blueAccent.withOpacity(0.2),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.edit, color: Colors.blueAccent, size: 28),
      ),
      secondaryBackground: Container(
        color: Colors.redAccent.withOpacity(0.2),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.redAccent, size: 28),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Edit Goal
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GoalFormScreen(goal: goal),
            ),
          );
          return false; // Don't dismiss instantly
        } else {
          // Confirm Delete
          return await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: kCardBg,
                  title: const Text('Delete Goal', style: TextStyle(color: Colors.black87)),
                  content: Text(
                    'Are you sure you want to delete "${goal.name}"?',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  actions: [
                    TextButton(
                      child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    TextButton(
                      child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ],
                ),
              ) ??
              false;
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          provider.deleteGoal(goal.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Goal "${goal.name}" deleted')),
          );
        }
      },
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GoalDetailScreen(goalId: goal.id),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Header (Goal Title + Required SIP or tag)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Goal Name & Badges
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goal.name,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // Subtitle timeline summary
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: kMoneyGreen.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  goal.account,
                                  style: const TextStyle(
                                    color: kMoneyGreen,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                remainingMonths == 0 ? 'Achieved!' : '$remainingMonths mo left',
                                style: const TextStyle(color: Colors.black38, fontSize: 11),
                              ),
                              const SizedBox(width: 6),
                              const Text('•', style: TextStyle(color: Colors.black26, fontSize: 11)),
                              const SizedBox(width: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(healthIcon, color: healthColor, size: 10),
                                  const SizedBox(width: 2),
                                  Text(
                                    healthText,
                                    style: TextStyle(
                                      color: healthColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Required SIP Column
                    if (reqSip > 0)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'REQUIRED SIP',
                            style: TextStyle(
                              color: Colors.black38,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _currencyFormatter.format(reqSip),
                            style: const TextStyle(
                              color: kMoneyGreen,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Text(
                            '/ month',
                            style: TextStyle(color: Colors.black38, fontSize: 8),
                          ),
                        ],
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: kMoneyGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '🎉 Fully Funded',
                          style: TextStyle(
                            color: kMoneyGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Row 2: Progress indicator
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress / 100.0,
                          minHeight: 4,
                          backgroundColor: Colors.black12,
                          valueColor: AlwaysStoppedAnimation<Color>(healthColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${progress.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: healthColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Row 3: Progress text label (X saved of Y target)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_currencyFormatter.format(goal.currentSavings)} saved of ${_currencyFormatter.format(target)}',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(color: Colors.black.withOpacity(0.04), height: 1),
                const SizedBox(height: 10),

                // Row 4: Footer (Original budget + Update action)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Original Budget: ${_currencyFormatter.format(goal.targetCost)}',
                      style: const TextStyle(
                        color: Colors.black38,
                        fontSize: 10,
                      ),
                    ),
                    InkWell(
                      onTap: () => _showQuickUpdateSavingsDialog(context, goal, provider),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.edit_note, color: kMoneyGreen, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Update Savings',
                              style: TextStyle(
                                color: kMoneyGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Backup & Restore dialog code
  void _showBackupRestoreDialog(BuildContext context, GoalProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        final textController = TextEditingController();
        return AlertDialog(
          backgroundColor: kCardBg,
          title: const Text('Backup & Restore Goals', style: TextStyle(color: Colors.black87)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Copy this JSON code block to backup your data, or paste a previously exported JSON block below to restore it.',
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: textController,
                  maxLines: 6,
                  style: TextStyle(color: kMoneyGreen, fontSize: 12, fontFamily: 'monospace'),
                  decoration: const InputDecoration(
                    hintText: 'Paste backup JSON here...',
                    hintStyle: TextStyle(color: Colors.black26),
                    fillColor: kScaffoldBg,
                    filled: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('Copy Current Backup', style: TextStyle(color: kMoneyGreen)),
              onPressed: () {
                final backupStr = provider.exportData();
                // Copy to clipboard
                textController.text = backupStr;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Backup JSON copied to text field!')),
                );
              },
            ),
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kMoneyGreen, foregroundColor: Colors.white),
              child: const Text('Restore JSON'),
              onPressed: () {
                if (textController.text.trim().isNotEmpty) {
                  final success = provider.importData(textController.text);
                  if (success) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Data restored successfully!')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to restore. Invalid JSON!')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
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
            Text('Enter new savings balance for "${goal.name}":', style: const TextStyle(color: Colors.black54, fontSize: 13)),
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
            onPressed: () {
              final val = double.tryParse(controller.text.trim());
              if (val != null && val >= 0) {
                final updated = goal.copyWith(currentSavings: val);
                provider.updateGoal(updated);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Savings balance for "${goal.name}" updated successfully!')),
                );
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
