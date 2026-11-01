import 'package:flutter/material.dart';
import '../constants.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/goal_model.dart';
import '../providers/goal_provider.dart';
import '../providers/notification_provider.dart';
import '../widgets/app_logo.dart';
import '../widgets/multipoint_progress_bar.dart';
import '../widgets/pwa_install_banner.dart';
import '../data/spreadsheet_goals.dart';
import 'family_screen.dart';
import 'goal_detail_screen.dart';
import 'goal_form_screen.dart';
import 'notifications_screen.dart';
import '../app_routes.dart';

enum _SipFilter { all, needsSip, fullyFunded }
enum _SortOrder { targetDate, requiredSip, health, progress, name }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedAccount = 'All';
  _SipFilter _sipFilter = _SipFilter.all;
  _SortOrder _sortOrder = _SortOrder.targetDate;
  bool _isSettingsExpanded = false;

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GoalProvider>(context);
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final theme = Theme.of(context);

    // Filter and sort goals by family member, SIP status and sort parameters
    final filteredGoals = _filterAndSortGoals(provider);

    final double filteredTotalSavings = filteredGoals.fold(
      0.0,
      (sum, g) => sum + g.currentSavings,
    );
    final double filteredTotalTarget = filteredGoals.fold(
      0.0,
      (sum, g) => sum + g.getInflationAdjustedTarget(provider.globalInflation),
    );

    // Dynamically fetch account list
    final familyMembers = ['All', ...provider.familyMemberLabels];

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
            )
          ],
        ),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: kMoneyGreen),
                tooltip: 'AI Suggestions',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                  );
                },
              ),
              if (notificationProvider.unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      notificationProvider.unreadCount > 9
                          ? '9+'
                          : '${notificationProvider.unreadCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
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
          PopupMenuButton<String>(
            tooltip: 'Profile & Settings',
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            color: Colors.white,
            surfaceTintColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: _buildAppBarProfileAvatar(provider),
            ),
            onSelected: (value) async {
              if (value == 'family') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FamilyScreen()),
                );
              } else if (value == 'privacy') {
                Navigator.pushNamed(context, AppRoutes.privacy);
              } else if (value == 'logout') {
                await provider.signOut();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                enabled: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: kMoneyGreen.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.group_outlined,
                          color: kMoneyGreen,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              provider.family?.name ?? 'My Family',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A), // slate-900
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              provider.currentMember != null
                                  ? '${provider.currentMember!.displayName ?? provider.currentMember!.label} • Member'
                                  : 'Family Portfolio',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (provider.isAuthenticated) ...[
                const PopupMenuDivider(height: 1),
                PopupMenuItem<String>(
                  value: 'family',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: kMoneyGreen.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.people_alt_outlined, color: kMoneyGreen, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Manage Family',
                        style: TextStyle(
                          color: Color(0xFF1E293B), // slate-800
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(height: 1),
                PopupMenuItem<String>(
                  value: 'privacy',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: kMoneyGreen.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.shield_outlined, color: kMoneyGreen, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Privacy Policy',
                        style: TextStyle(
                          color: Color(0xFF1E293B), // slate-800
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(height: 1),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Sign Out',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
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
              onRefresh: provider.refreshFromCloud,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  // PWA install prompt (web only)
                  const PwaInstallBanner(),

                  // Welcome Greeting Header
                  _buildGreetingHeader(provider),

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

                  // Unified Filter Bar
                  _buildUnifiedFilterBar(familyMembers),

                  // Goal Cards Title & Stats
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_selectedAccount == 'All' ? 'All' : "$_selectedAccount's"} Goals (${filteredGoals.length})',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (filteredGoals.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    const TextSpan(
                                      text: 'Total Collected: ',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    TextSpan(
                                      text: _formatCompactInr(filteredTotalSavings),
                                      style: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    TextSpan(
                                      text: ' of ${_formatCompactInr(filteredTotalTarget)}',
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          'Tap for details · ··· to edit',
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
        onPressed: () async {
          final createdAccount = await Navigator.push<String>(
            context,
            MaterialPageRoute(
              builder: (context) => const GoalFormScreen(),
            ),
          );
          if (createdAccount != null && mounted) {
            setState(() => _selectedAccount = 'All');
          }
        },
      ),
    );
  }

  // Widget: Empty State UI
  Widget _buildEmptyState(BuildContext context) {
    final provider = Provider.of<GoalProvider>(context, listen: false);
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
            'Tap the button below to add your first financial life goal, or load the spreadsheet goals.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => _importSpreadsheetGoals(context, provider),
            icon: const Icon(Icons.table_chart_outlined, color: kMoneyGreen),
            label: Text(
              'Load spreadsheet goals (${SpreadsheetGoals.all.length})',
              style: const TextStyle(color: kMoneyGreen, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: kMoneyGreen),
            ),
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
        ],
      ),
    );
  }

  Future<void> _importSpreadsheetGoals(BuildContext context, GoalProvider provider) async {
    final replace = provider.goals.isNotEmpty;
    final confirmed = !replace ||
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: kCardBg,
            title: const Text('Update spreadsheet goals?', style: TextStyle(color: Colors.black87)),
            content: Text(
              'This will update the ${SpreadsheetGoals.all.length} spreadsheet goals if they already exist, or add any that are missing.',
              style: const TextStyle(color: Colors.black54),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Update', style: TextStyle(color: kMoneyGreen)),
              ),
            ],
          ),
        ) ==
            true;

    if (!confirmed || !context.mounted) return;

    try {
      final count = await provider.importSpreadsheetGoals();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loaded $count spreadsheet goals.')),
      );
      setState(() => _selectedAccount = 'All');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load goals: $e')),
      );
    }
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

  // Get icon based on goal name
  IconData _getGoalIcon(String goalName) {
    final name = goalName.toLowerCase();
    if (name.contains('bali') || name.contains('travel') || name.contains('trip') || name.contains('vacation') || name.contains('flight')) {
      return Icons.flight_takeoff_rounded;
    } else if (name.contains('home') || name.contains('house') || name.contains('flat') || name.contains('land')) {
      return Icons.home_rounded;
    } else if (name.contains('emergency') || name.contains('medical') || name.contains('hospital') || name.contains('health') || name.contains('security')) {
      return Icons.shield_rounded;
    } else if (name.contains('education') || name.contains('school') || name.contains('college') || name.contains('university') || name.contains('study')) {
      return Icons.school_rounded;
    } else if (name.contains('wedding') || name.contains('shadi') || name.contains('marriage')) {
      return Icons.favorite_rounded;
    } else if (name.contains('car') || name.contains('bike') || name.contains('vehicle')) {
      return Icons.directions_car_rounded;
    } else if (name.contains('retirement') || name.contains('pension') || name.contains('old')) {
      return Icons.elderly_rounded;
    } else {
      return Icons.star_rounded;
    }
  }

  // Widget: Header Greeting Header
  Widget _buildGreetingHeader(GoalProvider provider) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WELCOME BACK 👋',
                  style: TextStyle(
                    color: Color(0xFF64748B), // slate-500
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  provider.family?.name ?? 'My Family Portfolio',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF0F172A), // slate-900
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // Widget: Family Avatars stack representation
  Widget _buildFamilyAvatarStack(GoalProvider provider) {
    final members = provider.familyMembers;
    if (members.isEmpty) {
      return Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: kMoneyGreen,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.person, color: Colors.white, size: 20),
      );
    }

    final displayCount = members.length > 3 ? 3 : members.length;
    final widgets = <Widget>[];

    for (var i = 0; i < displayCount; i++) {
      final member = members[i];
      final memberName = member.displayName?.trim().isNotEmpty == true
          ? member.displayName!.trim()
          : member.label;
      final initials = memberName.isNotEmpty
          ? memberName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase()
          : '?';
      
      final colors = [
        const Color(0xFF3B82F6), // blue
        const Color(0xFF10B981), // emerald
        const Color(0xFFF59E0B), // amber
        const Color(0xFFEC4899), // pink
        const Color(0xFF8B5CF6), // violet
      ];
      final bgColor = colors[member.userId.hashCode % colors.length];

      widgets.add(
        Positioned(
          right: i * 20.0,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              initials.length > 2 ? initials.substring(0, 2) : initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      );
    }

    if (members.length > 3) {
      widgets.add(
        Positioned(
          right: 3 * 20.0,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF64748B),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              '+${members.length - 3}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    final totalWidth = 36.0 + (displayCount - 1) * 20.0 + (members.length > 3 ? 20.0 : 0);

    return SizedBox(
      width: totalWidth,
      height: 36,
      child: Stack(
        clipBehavior: Clip.none,
        children: widgets.reversed.toList(),
      ),
    );
  }

  // Widget: App Bar Profile Avatar for dropdown trigger
  Widget _buildAppBarProfileAvatar(GoalProvider provider) {
    final member = provider.currentMember;
    if (member == null) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: kMoneyGreen.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.person_outline, color: kMoneyGreen, size: 20),
      );
    }

    final memberName = member.displayName?.trim().isNotEmpty == true
        ? member.displayName!.trim()
        : member.label;
    final initials = memberName.isNotEmpty
        ? memberName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase()
        : '?';

    final colors = [
      const Color(0xFF3B82F6), // blue
      const Color(0xFF10B981), // emerald
      const Color(0xFFF59E0B), // amber
      const Color(0xFFEC4899), // pink
      const Color(0xFF8B5CF6), // violet
    ];
    final bgColor = colors[member.userId.hashCode % colors.length];

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        initials.length > 2 ? initials.substring(0, 2) : initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Widget: Goal Progress Ring
  Widget _buildGoalProgressRing(GoalModel goal, double progressPercent, Color fillColor) {
    final iconData = _getGoalIcon(goal.name);
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              value: progressPercent / 100.0,
              strokeWidth: 3.5,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(fillColor),
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: fillColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              iconData,
              color: fillColor,
              size: 15,
            ),
          ),
        ],
      ),
    );
  }

  // Widget: Merged financial summary card
  Widget _buildFinancialSummaryGrid(GoalProvider provider) {
    final double requiredSip = provider.totalRequiredSIP;
    final double requiredLumpSum = provider.totalRequiredLumpSum;
    final double totalTarget = provider.goals.fold(
      0.0,
      (sum, g) => sum + g.getInflationAdjustedTarget(provider.globalInflation),
    );
    final double totalSaved = provider.totalWealthInvested;
    final double remaining = (totalTarget - totalSaved).clamp(0.0, double.infinity);
    final double progressPercent = totalTarget > 0 ? (totalSaved / totalTarget * 100).clamp(0, 100) : 0.0;
    final double shortfallPercent = (100 - progressPercent).clamp(0, 100);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.12),
              blurRadius: 15,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.bolt_rounded,
                                color: Color(0xFF34D399),
                                size: 13,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Flexible(
                              child: Text(
                                'REQUIRED MONTHLY SIP TODAY',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: _currencyFormatter.format(requiredSip),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const TextSpan(
                                text: '/mo',
                                style: TextStyle(
                                  color: Color(0xFFCBD5E1),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (requiredLumpSum > 0) ...[
                          const SizedBox(height: 6),
                          Text(
                            'or ${_formatCompactInr(requiredLumpSum)} today to fully fund',
                            style: const TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildOverallProgressRing(provider, progressPercent),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(height: 1, color: Colors.white.withOpacity(0.08)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSummaryStat(
                      label: 'Collected Till Date',
                      value: _formatCompactInr(totalSaved),
                      subtext: '${progressPercent.toStringAsFixed(0)}% of ${_formatCompactInr(totalTarget)} target',
                      accent: const Color(0xFF34D399),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: Colors.white.withOpacity(0.08),
                  ),
                  Expanded(
                    child: _buildSummaryStat(
                      label: 'Remaining',
                      value: _formatCompactInr(remaining),
                      subtext: '${shortfallPercent.toStringAsFixed(0)}% shortfall',
                      accent: const Color(0xFFFBBF24),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
              child: Text(
                'Assumes ${provider.globalInflation.toStringAsFixed(1)}% inflation · ${provider.globalReturn.toStringAsFixed(0)}% return rate',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStat({
    required String label,
    required String value,
    required String subtext,
    required Color accent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: accent.withOpacity(0.9),
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          subtext,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildOverallProgressRing(GoalProvider provider, double progressPercent) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.02),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.5),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              value: progressPercent / 100.0,
              strokeWidth: 5.5,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${progressPercent.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const Text(
                'FUNDED',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 6,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required double progress,
    required String subtext,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.012),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(1),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 2.5,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(iconColor),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtext,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  bool _goalNeedsSip(GoalModel goal, GoalProvider provider) {
    return goal.getRequiredSIP(
          provider.today,
          provider.globalInflation,
          provider.globalReturn,
        ) >
        0;
  }

  String _formatMonthsLeft(int remainingMonths) {
    if (remainingMonths == 0) return 'Achieved!';
    if (remainingMonths > 24) {
      final double years = remainingMonths / 12.0;
      if (years % 1 == 0) {
        return '${years.toInt()} years left';
      } else {
        return '${years.toStringAsFixed(1)} years left';
      }
    }
    return '$remainingMonths mo left';
  }

  List<GoalModel> _filterAndSortGoals(GoalProvider provider) {
    var goals = provider.goalsForMember(_selectedAccount);

    // 1. Filter by SIP Status
    switch (_sipFilter) {
      case _SipFilter.needsSip:
        goals = goals.where((g) => _goalNeedsSip(g, provider)).toList();
        break;
      case _SipFilter.fullyFunded:
        goals = goals.where((g) => !_goalNeedsSip(g, provider)).toList();
        break;
      case _SipFilter.all:
        break;
    }

    // 2. Sort goals
    goals.sort((a, b) {
      switch (_sortOrder) {
        case _SortOrder.targetDate:
          return a.targetDate.compareTo(b.targetDate);
        case _SortOrder.requiredSip:
          final sipA = a.getRequiredSIP(provider.today, provider.globalInflation, provider.globalReturn);
          final sipB = b.getRequiredSIP(provider.today, provider.globalInflation, provider.globalReturn);
          return sipB.compareTo(sipA); // Descending (highest first)
        case _SortOrder.health:
          final healthA = a.getHealth(provider.today, provider.globalInflation, provider.globalReturn).index;
          final healthB = b.getHealth(provider.today, provider.globalInflation, provider.globalReturn).index;
          return healthB.compareTo(healthA); // Descending (Behind first)
        case _SortOrder.progress:
          final progressA = a.getPercentDone(provider.today, provider.globalInflation, provider.globalReturn);
          final progressB = b.getPercentDone(provider.today, provider.globalInflation, provider.globalReturn);
          return progressA.compareTo(progressB); // Ascending (least progress first)
        case _SortOrder.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });

    return goals;
  }

  // Widget: Unified Filter Bar (Family Member + SIP Status + Sorting Dropdown Pills)
  Widget _buildUnifiedFilterBar(List<String> accounts) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Family Member Dropdown Pill
          PopupMenuButton<String>(
            initialValue: _selectedAccount,
            offset: const Offset(0, 36),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            color: Colors.white,
            surfaceTintColor: Colors.white,
            onSelected: (value) {
              setState(() {
                _selectedAccount = value;
              });
            },
            itemBuilder: (context) {
              return accounts.map((acc) {
                return PopupMenuItem<String>(
                  value: acc,
                  child: Text(
                    acc == 'All' ? 'All' : acc,
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: kCardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.015),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people_outline, size: 14, color: kMoneyGreen),
                  const SizedBox(width: 6),
                  Text(
                    _selectedAccount == 'All' ? 'All' : _selectedAccount,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, size: 14, color: Color(0xFF94A3B8)),
                ],
              ),
            ),
          ),

          // SIP Filter Dropdown Pill
          PopupMenuButton<_SipFilter>(
            initialValue: _sipFilter,
            offset: const Offset(0, 36),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            color: Colors.white,
            surfaceTintColor: Colors.white,
            onSelected: (value) {
              setState(() {
                _sipFilter = value;
              });
            },
            itemBuilder: (context) {
              return const [
                PopupMenuItem<_SipFilter>(
                  value: _SipFilter.all,
                  child: Text(
                    'All Goals',
                    style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                PopupMenuItem<_SipFilter>(
                  value: _SipFilter.needsSip,
                  child: Text(
                    'Needs SIP',
                    style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                PopupMenuItem<_SipFilter>(
                  value: _SipFilter.fullyFunded,
                  child: Text(
                    'Fully Funded',
                    style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ];
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: kCardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.015),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.filter_alt_outlined, size: 14, color: kMoneyGreen),
                  const SizedBox(width: 6),
                  Text(
                    _sipFilter == _SipFilter.all
                        ? 'Status'
                        : _sipFilter == _SipFilter.needsSip
                            ? 'Needs SIP'
                            : 'Fully Funded',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, size: 14, color: Color(0xFF94A3B8)),
                ],
              ),
            ),
          ),

          // Sorting Dropdown Pill
          PopupMenuButton<_SortOrder>(
            initialValue: _sortOrder,
            offset: const Offset(0, 36),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            color: Colors.white,
            surfaceTintColor: Colors.white,
            onSelected: (value) {
              setState(() {
                _sortOrder = value;
              });
            },
            itemBuilder: (context) {
              return const [
                PopupMenuItem<_SortOrder>(
                  value: _SortOrder.targetDate,
                  child: Text(
                    'Sort: Target Date',
                    style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                PopupMenuItem<_SortOrder>(
                  value: _SortOrder.requiredSip,
                  child: Text(
                    'Sort: Required SIP',
                    style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                PopupMenuItem<_SortOrder>(
                  value: _SortOrder.health,
                  child: Text(
                    'Sort: Health Status',
                    style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                PopupMenuItem<_SortOrder>(
                  value: _SortOrder.progress,
                  child: Text(
                    'Sort: Progress %',
                    style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                PopupMenuItem<_SortOrder>(
                  value: _SortOrder.name,
                  child: Text(
                    'Sort: Name',
                    style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ];
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: kCardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.015),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sort_rounded, size: 14, color: kMoneyGreen),
                  const SizedBox(width: 6),
                  Text(
                    _sortOrder == _SortOrder.targetDate
                        ? 'Target Date'
                        : _sortOrder == _SortOrder.requiredSip
                            ? 'Required SIP'
                            : _sortOrder == _SortOrder.health
                                ? 'Health'
                                : _sortOrder == _SortOrder.progress
                                    ? 'Progress %'
                                    : 'Name',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, size: 14, color: Color(0xFF94A3B8)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCompactInr(double value) {
    final abs = value.abs();
    if (abs >= 10000000) {
      return '₹${(value / 10000000).toStringAsFixed(1)}Cr';
    }
    if (abs >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(1)}L';
    }
    return _currencyFormatter.format(value);
  }

  Future<void> _confirmDeleteGoal(BuildContext context, GoalModel goal, GoalProvider provider) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: kCardBg,
            title: const Text('Delete Goal', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
            content: Text(
              'Are you sure you want to delete "${goal.name}"?',
              style: const TextStyle(color: Color(0xFF475569)),
            ),
            actions: [
              TextButton(
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                onPressed: () => Navigator.pop(context, false),
              ),
              TextButton(
                child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !context.mounted) return;
    provider.deleteGoal(goal.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Goal "${goal.name}" deleted')),
    );
  }

  // Widget: Goal Card list item
  Widget _buildGoalCard(BuildContext context, GoalModel goal, GoalProvider provider) {
    final double inflationTarget = goal.getInflationAdjustedTarget(provider.globalInflation);
    final double reqSip = goal.getRequiredSIP(provider.today, provider.globalInflation, provider.globalReturn);
    final double reqLumpSum = goal.getRequiredLumpSumToday(provider.today, provider.globalInflation, provider.globalReturn);
    final int remainingMonths = goal.getRemainingMonths(provider.today);
    final health = goal.getHealth(provider.today, provider.globalInflation, provider.globalReturn);
    final progressPercent = goal.getPercentDone(provider.today, provider.globalInflation, provider.globalReturn);
    final barProgress = inflationTarget > 0
        ? (goal.currentSavings / inflationTarget).clamp(0.0, 1.0)
        : 0.0;

    final bool hasAddedSip = goal.isLastInvestmentApproxSIP(
      provider.today,
      provider.globalInflation,
      provider.globalReturn,
    );

    final Color healthColor;
    final String healthText;
    switch (health) {
      case GoalHealth.onTrack:
        healthColor = const Color(0xFF10B981);
        healthText = 'On Track';
        break;
      case GoalHealth.needsAttention:
        healthColor = const Color(0xFFF59E0B);
        healthText = 'Attentive';
        break;
      case GoalHealth.behindSchedule:
        healthColor = const Color(0xFFEF4444);
        healthText = 'Behind';
        break;
    }

    final memberLabel = provider.resolveMemberLabel(goal.account);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GoalDetailScreen(goalId: goal.id),
          ),
        );
      },
      onLongPress: () => _showQuickUpdateSavingsDialog(context, goal, provider),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Goal Identity Header
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 10),
              child: Row(
                children: [
                  _buildGoalProgressRing(goal, progressPercent, healthColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                goal.name,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: healthColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                healthText,
                                style: TextStyle(
                                  color: healthColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$memberLabel · ${_formatMonthsLeft(remainingMonths)}',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    offset: const Offset(0, 36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: kCardBg,
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => GoalFormScreen(goal: goal)),
                          );
                          break;
                        case 'savings':
                          _showQuickUpdateSavingsDialog(context, goal, provider);
                          break;
                        case 'delete':
                          _confirmDeleteGoal(context, goal, provider);
                          break;
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'savings', child: Text('Update savings')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
                      ),
                    ],
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.more_horiz, color: Color(0xFF94A3B8), size: 18),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Saved Till Date & Progress Section
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 13,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'SAVED TILL DATE',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatCompactInr(goal.currentSavings),
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${(barProgress * 100).toStringAsFixed(0)}% of ${_formatCompactInr(inflationTarget)}',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: barProgress,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(healthColor),
                    ),
                  ),
                ],
              ),
            ),

            // 3. Settlement Options (Monthly SIP or One-Time Shot)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: reqSip > 0
                    ? Row(
                        children: [
                          // Option 1: Monthly SIP
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_month_outlined,
                                      size: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'MONTHLY SIP',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    if (hasAddedSip) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFECFDF5),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check_circle_outline_rounded, size: 10, color: Color(0xFF059669)),
                                            SizedBox(width: 2.5),
                                            Text(
                                              'SIP added',
                                              style: TextStyle(
                                                color: Color(0xFF059669),
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: _currencyFormatter.format(reqSip),
                                        style: const TextStyle(
                                          color: Color(0xFF0F172A),
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const TextSpan(
                                        text: '/mo',
                                        style: TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),

                          // Vertical divider
                          Container(
                            height: 32,
                            width: 1,
                            color: const Color(0xFFE2E8F0),
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                          ),

                          // Option 2: One-Time Shot
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.bolt_rounded,
                                      size: 13,
                                      color: Color(0xFF00A37B),
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      'ONE-TIME SHOT',
                                      style: TextStyle(
                                        color: Color(0xFF00A37B),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: _formatCompactInr(reqLumpSum),
                                        style: const TextStyle(
                                          color: Color(0xFF00A37B),
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const TextSpan(
                                        text: ' to settle',
                                        style: TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Goal Settled & Fully Funded! 🎉',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
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
