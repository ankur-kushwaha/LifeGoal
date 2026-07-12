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

  // Widget: Financial Summary Dashboard cards
  Widget _buildFinancialSummaryGrid(GoalProvider provider) {
    final double requiredSip = provider.totalRequiredSIP;

    double totalTarget = provider.goals.fold(0.0, (sum, g) => sum + g.getInflationAdjustedTarget(provider.globalInflation));
    double totalSaved = provider.totalWealthInvested;
    double progressPercent = totalTarget > 0 ? (totalSaved / totalTarget * 100).clamp(0, 100) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          // Premium Fintech Hero Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                              const Text(
                                "REQUIRED MONTHLY SIP TODAY",
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _currencyFormatter.format(requiredSip),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Assumes ${provider.globalInflation.toStringAsFixed(1)}% inflation · ${provider.globalReturn.toStringAsFixed(0)}% return rate",
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Elegant Progress Ring
                    _buildOverallProgressRing(provider, progressPercent),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.015),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "SAVED",
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _currencyFormatter.format(provider.totalWealthInvested),
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${progressPercent.toStringAsFixed(0)}% of target",
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: progressPercent / 100.0,
                              strokeWidth: 3.5,
                              backgroundColor: const Color(0xFFE2E8F0),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                            ),
                            Text(
                              "${progressPercent.toStringAsFixed(0)}%",
                              style: const TextStyle(
                                color: Color(0xFF3B82F6),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.015),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "REMAINING",
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _currencyFormatter.format(provider.totalRemainingInvestment),
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${(100 - progressPercent).toStringAsFixed(0)}% shortfall",
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: (100 - progressPercent) / 100.0,
                              strokeWidth: 3.5,
                              backgroundColor: const Color(0xFFE2E8F0),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                            ),
                            Text(
                              "${(100 - progressPercent).toStringAsFixed(0)}%",
                              style: const TextStyle(
                                color: Color(0xFFF59E0B),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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

  // Widget: Goal Card list item
  Widget _buildGoalCard(BuildContext context, GoalModel goal, GoalProvider provider) {
    final double inflationTarget = goal.getInflationAdjustedTarget(provider.globalInflation);
    final double projectedSavings = goal.getProjectedSavings(provider.today, provider.globalReturn);
    final double reqSip = goal.getRequiredSIP(provider.today, provider.globalInflation, provider.globalReturn);
    final int remainingMonths = goal.getRemainingMonths(provider.today);
    final health = goal.getHealth(provider.today, provider.globalInflation, provider.globalReturn);

    Color healthColor;
    String healthText;
    IconData healthIcon;
    switch (health) {
      case GoalHealth.onTrack:
        healthColor = const Color(0xFF10B981);
        healthText = 'On Track';
        healthIcon = Icons.check_circle_rounded;
        break;
      case GoalHealth.needsAttention:
        healthColor = const Color(0xFFF59E0B);
        healthText = 'Attention';
        healthIcon = Icons.warning_rounded;
        break;
      case GoalHealth.behindSchedule:
        healthColor = const Color(0xFFEF4444);
        healthText = 'Behind';
        healthIcon = Icons.error_rounded;
        break;
    }

    final progressPercent = goal.getPercentDone(provider.today, provider.globalInflation, provider.globalReturn);

    final memberColors = [
      const Color(0xFF3B82F6), // blue
      const Color(0xFF10B981), // emerald
      const Color(0xFFF59E0B), // amber
      const Color(0xFFEC4899), // pink
      const Color(0xFF8B5CF6), // violet
    ];
    final memberIndex = provider.familyMembers.indexWhere((m) => m.matchesAccount(goal.account));
    final memberColor = memberIndex != -1 ? memberColors[memberIndex % memberColors.length] : const Color(0xFF64748B);

    return Dismissible(
      key: Key(goal.id),
      direction: DismissDirection.horizontal,
      background: Container(
        color: const Color(0xFF3B82F6).withOpacity(0.1),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: const Icon(Icons.edit_rounded, color: Color(0xFF3B82F6), size: 28),
      ),
      secondaryBackground: Container(
        color: const Color(0xFFEF4444).withOpacity(0.1),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 28),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GoalFormScreen(goal: goal),
            ),
          );
          return false;
        } else {
          return await showDialog<bool>(
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
        onLongPress: () => _showQuickUpdateSavingsDialog(context, goal, provider),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.015),
                blurRadius: 12,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildGoalProgressRing(goal, progressPercent, healthColor),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goal.name,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: memberColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: memberColor.withOpacity(0.2), width: 0.5),
                                ),
                                child: Text(
                                  provider.resolveMemberLabel(goal.account),
                                  style: TextStyle(
                                    color: memberColor,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              Text(
                                _formatMonthsLeft(remainingMonths),
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              // Small visual separator dot represented as a circular widget
                              Container(
                                width: 3,
                                height: 3,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFCBD5E1),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(healthIcon, color: healthColor, size: 11),
                                  const SizedBox(width: 3),
                                  Text(
                                    healthText,
                                    style: TextStyle(
                                      color: healthColor,
                                      fontSize: 10.5,
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
                    const SizedBox(width: 10),
                    if (reqSip > 0)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'REQUIRED SIP',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _currencyFormatter.format(reqSip),
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const Text(
                            '/ month',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 8.5, fontWeight: FontWeight.w500),
                          ),
                        ],
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '🎉 Fully Funded',
                              style: TextStyle(
                                color: Color(0xFF065F46),
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.savings_outlined, color: Color(0xFF94A3B8), size: 12),
                    const SizedBox(width: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: _currencyFormatter.format(goal.currentSavings),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const TextSpan(
                            text: ' saved of ',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          TextSpan(
                            text: _currencyFormatter.format(inflationTarget),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
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
