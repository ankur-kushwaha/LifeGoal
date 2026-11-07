import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../models/admin_config_model.dart';
import '../models/family_model.dart';
import '../models/goal_model.dart';
import '../models/notification_model.dart';
import '../providers/admin_provider.dart';
import '../providers/goal_provider.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _pinController = TextEditingController();
  bool _obscurePin = true;

  // Local editable copies of config values
  late double _inflation;
  late double _expectedReturn;
  late DateTime _planningDate;
  late String _currency;
  late int _emergencyMonths;
  late double _safeWithdrawalRate;

  late String _aiProvider;
  late String _aiModel;
  late int _scheduledHour;
  late int _scheduledMinute;
  late String _aiAdvisorTone;
  late bool _autoNotifications;
  late bool _forceLocalAI;
  late TextEditingController _apiKeyController;

  late bool _maintenanceMode;
  late TextEditingController _maintenanceMsgController;
  late bool _allowRegistrations;
  late bool _pwaBanner;
  late bool _scenarioSimulator;
  late bool _strictGoalDelete;
  late bool _analyticsEnabled;

  late TextEditingController _newPinController;
  late List<String> _adminEmails;
  final _newEmailController = TextEditingController();
  final _familySearchController = TextEditingController();

  bool _initialized = false;
  bool _isTestingAi = false;
  bool _hasFetchedFamilies = false;
  AppNotification? _testedNotification;

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _apiKeyController = TextEditingController();
    _maintenanceMsgController = TextEditingController();
    _newPinController = TextEditingController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pinController.dispose();
    _apiKeyController.dispose();
    _maintenanceMsgController.dispose();
    _newPinController.dispose();
    _newEmailController.dispose();
    _familySearchController.dispose();
    super.dispose();
  }

  void _syncFromConfig(AdminConfig config) {
    _inflation = config.defaultInflationRate;
    _expectedReturn = config.defaultExpectedReturn;
    _planningDate = config.defaultPlanningDate;
    _currency = config.currencySymbol;
    _emergencyMonths = config.emergencyFundMonthsDefault;
    _safeWithdrawalRate = config.safeWithdrawalRate;

    _aiProvider = config.aiProvider;
    _aiModel = config.aiModel;
    _scheduledHour = config.scheduledNotificationHour;
    _scheduledMinute = config.scheduledNotificationMinute;
    _aiAdvisorTone = config.aiAdvisorTone;
    _autoNotifications = config.autoNotificationsEnabled;
    _forceLocalAI = config.forceLocalAIFallback;
    _apiKeyController.text = config.customOpenRouterApiKey;

    _maintenanceMode = config.maintenanceMode;
    _maintenanceMsgController.text = config.maintenanceMessage;
    _allowRegistrations = config.allowNewRegistrations;
    _pwaBanner = config.pwaPromptEnabled;
    _scenarioSimulator = config.scenarioSimulatorEnabled;
    _strictGoalDelete = config.strictAdminOnlyGoalDelete;
    _analyticsEnabled = config.analyticsTrackingEnabled;

    _newPinController.text = config.adminPin;
    _adminEmails = List.from(config.superAdminEmails);

    _initialized = true;
  }

  AdminConfig _buildCurrentConfig(AdminConfig original) {
    return original.copyWith(
      defaultInflationRate: _inflation,
      defaultExpectedReturn: _expectedReturn,
      defaultPlanningDate: _planningDate,
      currencySymbol: _currency,
      emergencyFundMonthsDefault: _emergencyMonths,
      safeWithdrawalRate: _safeWithdrawalRate,
      aiProvider: _aiProvider,
      aiModel: _aiModel,
      scheduledNotificationHour: _scheduledHour,
      scheduledNotificationMinute: _scheduledMinute,
      aiAdvisorTone: _aiAdvisorTone,
      autoNotificationsEnabled: _autoNotifications,
      forceLocalAIFallback: _forceLocalAI,
      customOpenRouterApiKey: _apiKeyController.text.trim(),
      maintenanceMode: _maintenanceMode,
      maintenanceMessage: _maintenanceMsgController.text.trim(),
      allowNewRegistrations: _allowRegistrations,
      pwaPromptEnabled: _pwaBanner,
      scenarioSimulatorEnabled: _scenarioSimulator,
      strictAdminOnlyGoalDelete: _strictGoalDelete,
      analyticsTrackingEnabled: _analyticsEnabled,
      adminPin: _newPinController.text.trim().isNotEmpty
          ? _newPinController.text.trim()
          : original.adminPin,
      superAdminEmails: _adminEmails,
      lastUpdated: DateTime.now(),
    );
  }

  Future<void> _saveAllChanges(AdminProvider adminProvider) async {
    final updated = _buildCurrentConfig(adminProvider.config);
    await adminProvider.saveConfig(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: kMoneyGreen,
          content: Text('Super Admin configuration saved successfully!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);
    final goalProvider = Provider.of<GoalProvider>(context);

    if (!_initialized && !adminProvider.isLoading) {
      _syncFromConfig(adminProvider.config);
    }

    // Auto-check current user's email if available
    String? userEmail;
    try {
      userEmail = goalProvider.authService.currentUserEmail;
    } catch (_) {}
    final isVerified = adminProvider.isSuperAdminVerified ||
        adminProvider.checkSuperAdminAccess(userEmail);

    if (isVerified && !_hasFetchedFamilies) {
      _hasFetchedFamilies = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        adminProvider.fetchAllFamilies(goalProvider);
      });
    }

    return Scaffold(
      backgroundColor: kScaffoldBg,
      appBar: AppBar(
        backgroundColor: kCardBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: kMoneyGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.admin_panel_settings,
                  color: kMoneyGreen, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Super Admin View',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          if (isVerified) ...[
            TextButton.icon(
              onPressed: () => _confirmReset(adminProvider),
              icon: const Icon(Icons.restart_alt, size: 18, color: Colors.black54),
              label: const Text('Reset', style: TextStyle(color: Colors.black54)),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kMoneyGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _saveAllChanges(adminProvider),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Save Changes',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
        bottom: isVerified
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: kMoneyGreen,
                unselectedLabelColor: Colors.black54,
                indicatorColor: kMoneyGreen,
                indicatorWeight: 3,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(icon: Icon(Icons.dashboard_outlined), text: 'Overview'),
                  Tab(icon: Icon(Icons.people_alt_outlined), text: 'All Families'),
                  Tab(icon: Icon(Icons.show_chart), text: 'Financial Engine'),
                  Tab(icon: Icon(Icons.auto_awesome), text: 'AI & Notifications'),
                  Tab(icon: Icon(Icons.flag_outlined), text: 'Feature Flags'),
                  Tab(icon: Icon(Icons.build_outlined), text: 'Data Tools'),
                ],
              )
            : null,
      ),
      body: adminProvider.isLoading
          ? const Center(child: CircularProgressIndicator(color: kMoneyGreen))
          : !isVerified
              ? _buildPinLockScreen(adminProvider, userEmail)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(adminProvider, goalProvider),
                    _buildAllFamiliesTab(adminProvider, goalProvider),
                    _buildFinancialEngineTab(adminProvider, goalProvider),
                    _buildAiNotificationTab(adminProvider, goalProvider),
                    _buildFeatureFlagsTab(adminProvider),
                    _buildDataToolsTab(adminProvider, goalProvider),
                  ],
                ),
    );
  }

  // ---------------------------------------------------------------------------
  // PIN LOCK / AUTHENTICATION GATE
  // ---------------------------------------------------------------------------
  Widget _buildPinLockScreen(AdminProvider adminProvider, String? userEmail) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: kMoneyGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 34,
                  color: kMoneyGreen,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Super Admin Access',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter the Super Admin PIN to configure global parameters, AI models, financial defaults, and feature flags.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _pinController,
                obscureText: _obscurePin,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Admin Security PIN',
                  hintText: 'Default PIN is 7788',
                  prefixIcon: const Icon(Icons.lock_outline, color: kMoneyGreen),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePin ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: Colors.black45,
                    ),
                    onPressed: () => setState(() => _obscurePin = !_obscurePin),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kMoneyGreen, width: 2),
                  ),
                ),
                onSubmitted: (_) {
                  final ok = adminProvider.verifyPin(_pinController.text);
                  if (ok) {
                    _syncFromConfig(adminProvider.config);
                  }
                },
              ),
              if (adminProvider.lastError != null) ...[
                const SizedBox(height: 12),
                Text(
                  adminProvider.lastError!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kMoneyGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    final ok = adminProvider.verifyPin(_pinController.text);
                    if (ok) {
                      _syncFromConfig(adminProvider.config);
                    }
                  },
                  child: const Text(
                    'Unlock Console',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Quick bypass button for testing/development
              TextButton.icon(
                onPressed: () {
                  adminProvider.grantAccessForTesting();
                  _syncFromConfig(adminProvider.config);
                },
                icon: const Icon(Icons.lock_open, size: 16, color: kMoneyGreen),
                label: Text(
                  userEmail != null
                      ? 'Auto-authorize as $userEmail'
                      : 'Developer One-Click Unlock',
                  style: const TextStyle(color: kMoneyGreen, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: OVERVIEW & HEALTH METRICS
  // ---------------------------------------------------------------------------
  Widget _buildOverviewTab(AdminProvider adminProvider, GoalProvider goalProvider) {
    final totalWealth = goalProvider.totalWealthInvested;
    final totalSip = goalProvider.totalRequiredSIP;
    final totalGoals = goalProvider.goals.length;
    final familyName = goalProvider.family?.name ?? 'Default Family';
    final membersCount = goalProvider.familyMembers.length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // System Status Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kMoneyGreen.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bolt_rounded, color: kMoneyGreen, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'System Status: Active',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: kMoneyGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            goalProvider.isFirebaseMode ? 'Cloud Firestore' : 'Local Storage',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'AI Provider: ${_aiProvider.toUpperCase()} (${_forceLocalAI ? "Fallback Local AI" : _aiModel}) • Active Family: $familyName',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          'Platform Metrics',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 12),

        // Metrics Grid
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 600;
            return GridView.count(
              crossAxisCount: isWide ? 4 : 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: isWide ? 1.5 : 1.3,
              children: [
                _buildMetricCard(
                  title: 'Total Tracked Corpus',
                  value: _currencyFormatter.format(totalWealth),
                  icon: Icons.account_balance_wallet_outlined,
                  color: kMoneyGreen,
                ),
                _buildMetricCard(
                  title: 'Total Required SIP',
                  value: '${_currencyFormatter.format(totalSip)}/mo',
                  icon: Icons.calendar_month_outlined,
                  color: const Color(0xFF2563EB),
                ),
                _buildMetricCard(
                  title: 'Active Goals',
                  value: '$totalGoals Goals',
                  icon: Icons.flag_circle_outlined,
                  color: const Color(0xFFD97706),
                ),
                _buildMetricCard(
                  title: 'Family Members',
                  value: '$membersCount Members',
                  icon: Icons.people_outline,
                  color: const Color(0xFF7C3AED),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 24),
        const Text(
          'Environment & Runtime Diagnostics',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 12),

        _buildSectionCard(
          children: [
            _buildDetailRow(
              'Firestore Project Database',
              kFirestoreDatabaseId,
              Icons.storage_outlined,
            ),
            const Divider(height: 20),
            _buildDetailRow(
              'Target Platform',
              kIsWeb ? 'Web Browser' : defaultTargetPlatform.name,
              Icons.devices_outlined,
            ),
            const Divider(height: 20),
            _buildDetailRow(
              'Baseline Financial Engine',
              'Inflation ${_inflation.toStringAsFixed(1)}% • Return ${_expectedReturn.toStringAsFixed(1)}%',
              Icons.trending_up,
            ),
            const Divider(height: 20),
            _buildDetailRow(
              'Reference Planning Date',
              DateFormat('dd MMMM yyyy').format(_planningDate),
              Icons.event_outlined,
            ),
            const Divider(height: 20),
            _buildDetailRow(
              'Config Last Synchronized',
              DateFormat('dd-MMM-yyyy hh:mm a').format(adminProvider.config.lastUpdated),
              Icons.history,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: ALL FAMILIES, MEMBERS & GOALS
  // ---------------------------------------------------------------------------
  Widget _buildAllFamiliesTab(
      AdminProvider adminProvider, GoalProvider goalProvider) {
    final families = adminProvider.allFamilies;
    final isLoading = adminProvider.isLoadingFamilies;

    final query = _familySearchController.text.trim().toLowerCase();
    final filtered = families.where((f) {
      if (query.isEmpty) return true;
      if (f.family.name.toLowerCase().contains(query)) {
        return true;
      }
      if (f.family.id.toLowerCase().contains(query)) {
        return true;
      }
      if (f.members.any((m) =>
          m.label.toLowerCase().contains(query) ||
          m.email.toLowerCase().contains(query))) {
        return true;
      }
      if (f.goals.any((g) =>
          g.name.toLowerCase().contains(query) ||
          g.account.toLowerCase().contains(query))) {
        return true;
      }
      return false;
    }).toList();

    final totalMembersAcrossFamilies =
        families.fold<int>(0, (sum, f) => sum + f.members.length);
    final totalGoalsAcrossFamilies =
        families.fold<int>(0, (sum, f) => sum + f.goals.length);
    final totalWealthAcrossFamilies =
        families.fold<double>(0.0, (sum, f) => sum + f.totalCurrentSavings);
    final totalSipAcrossFamilies =
        families.fold<double>(0.0, (sum, f) => sum + f.totalRequiredSip);

    return RefreshIndicator(
      color: kMoneyGreen,
      onRefresh: () => adminProvider.fetchAllFamilies(goalProvider),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildInfoBanner(
            'Multi-tenant view: Inspect all registered families, their members, roles, and tracked goals across the entire system.',
          ),
          const SizedBox(height: 16),

          // Aggregate Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kMoneyGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.hub_outlined, color: kMoneyGreen, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${families.length} Families Active',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '$totalMembersAcrossFamilies Members • $totalGoalsAcrossFamilies Goals • ${_currencyFormatter.format(totalWealthAcrossFamilies)} Total Corpus • ${_currencyFormatter.format(totalSipAcrossFamilies)}/mo SIP',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isLoading
                      ? null
                      : () => adminProvider.fetchAllFamilies(goalProvider),
                  icon: isLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.refresh, size: 16),
                  label: Text(isLoading ? 'Refreshing...' : 'Refresh Families'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Search Filter Bar
          TextField(
            controller: _familySearchController,
            decoration: InputDecoration(
              hintText: 'Search by family name, member email, or goal name...',
              prefixIcon: const Icon(Icons.search, color: kMoneyGreen),
              suffixIcon: _familySearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          _familySearchController.clear();
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: kCardBg,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kMoneyGreen, width: 2),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          if (isLoading && families.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: kMoneyGreen),
              ),
            )
          else if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(36),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: kCardBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text(
                    'No families found matching search query.',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black54),
                  ),
                ],
              ),
            )
          else
            ...filtered.map(
                (fam) => _buildFamilyCard(fam, adminProvider, goalProvider)),
        ],
      ),
    );
  }

  Widget _buildFamilyCard(FamilyOverviewData fam, AdminProvider adminProvider,
      GoalProvider goalProvider) {
    final family = fam.family;
    final members = fam.members;
    final goals = fam.goals;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding:
              const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kMoneyGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.family_restroom,
                color: kMoneyGreen, size: 24),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  family.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  'ID: ${family.id}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                tooltip: 'Delete Family',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _confirmDeleteFamily(context, fam, adminProvider, goalProvider),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildMiniBadge(
                  icon: Icons.people_outline,
                  label: '${members.length} Members',
                  color: const Color(0xFF2563EB),
                ),
                _buildMiniBadge(
                  icon: Icons.flag_outlined,
                  label: '${goals.length} Goals',
                  color: const Color(0xFFD97706),
                ),
                _buildMiniBadge(
                  icon: Icons.account_balance_wallet_outlined,
                  label: _currencyFormatter.format(fam.totalCurrentSavings),
                  color: kMoneyGreen,
                ),
                _buildMiniBadge(
                  icon: Icons.calendar_today_outlined,
                  label: '${_currencyFormatter.format(fam.totalRequiredSip)}/mo SIP',
                  color: const Color(0xFF7C3AED),
                ),
              ],
            ),
          ),
          children: [
            const Divider(height: 20),

            // 1. Members Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people, size: 18, color: Colors.black54),
                    const SizedBox(width: 6),
                    Text(
                      'Family Members (${members.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                Text(
                  members.isNotEmpty
                      ? 'Admin: ${members.firstWhere((m) => m.isAdmin, orElse: () => members.first).label}'
                      : 'No members',
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (members.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No registered members in this family.',
                    style: TextStyle(color: Colors.black45, fontSize: 13)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: members.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final member = members[index];
                  return _buildMemberTile(member);
                },
              ),

            const SizedBox(height: 20),

            // 2. Goals Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.track_changes,
                        size: 18, color: Colors.black54),
                    const SizedBox(width: 6),
                    Text(
                      'Family Financial Goals (${goals.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Overall Progress: ${fam.overallProgressPercentage.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: kMoneyGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (goals.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'No financial goals created yet for this family.',
                  style: TextStyle(color: Colors.black45, fontSize: 13),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: goals.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final goal = goals[index];
                  return _buildGoalAdminTile(goal, fam);
                },
              ),

            const SizedBox(height: 16),

            // Quick Actions Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                  ),
                  onPressed: () => _confirmDeleteFamily(context, fam, adminProvider, goalProvider),
                  icon: const Icon(Icons.delete_outline, size: 15),
                  label: const Text('Delete Family',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: family.id));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Copied Family ID: ${family.id}')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text('Copy Family ID',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteFamily(
    BuildContext context,
    FamilyOverviewData fam,
    AdminProvider adminProvider,
    GoalProvider goalProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: Colors.redAccent, size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delete Family',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                text: 'Are you sure you want to permanently delete ',
                children: [
                  TextSpan(
                    text: fam.family.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: '?\n\nThis will remove:'),
                ],
              ),
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 8),
            Text('• ${fam.members.length} registered member(s)',
                style: const TextStyle(fontSize: 13, color: Colors.black87)),
            Text('• ${fam.goals.length} tracked goal(s)',
                style: const TextStyle(fontSize: 13, color: Colors.black87)),
            Text('• All invite links and notifications',
                style: const TextStyle(fontSize: 13, color: Colors.black87)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Text(
                'This action is irreversible and immediately wipes all family data from Cloud Firestore and local storage.',
                style: TextStyle(fontSize: 12, color: Colors.redAccent),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success =
          await adminProvider.deleteFamily(fam.family.id, goalProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Deleted "${fam.family.name}" permanently.'
                : 'Failed to delete family: ${adminProvider.lastError ?? "Unknown error"}'),
            backgroundColor: success ? kMoneyGreen : Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildMiniBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberTile(FamilyMember member) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: member.isAdmin
                ? kMoneyGreen.withValues(alpha: 0.15)
                : const Color(0xFF64748B).withValues(alpha: 0.15),
            child: Text(
              member.label.isNotEmpty ? member.label[0].toUpperCase() : 'U',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: member.isAdmin ? kMoneyGreen : const Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      member.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: member.isAdmin
                            ? kMoneyGreen.withValues(alpha: 0.12)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        member.isAdmin ? 'Admin' : 'Member',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: member.isAdmin ? kMoneyGreen : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  member.email,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              member.memberProfile.employmentType.label,
              style: const TextStyle(fontSize: 10, color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalAdminTile(GoalModel goal, FamilyOverviewData fam) {
    final health = goal.getHealth(
        fam.referenceDate, fam.globalInflation, fam.globalReturn);
    final target = goal.getInflationAdjustedTarget(fam.globalInflation);
    final sip = goal.getRequiredSIP(
        fam.referenceDate, fam.globalInflation, fam.globalReturn);
    final progress = goal.getPercentDone(
        fam.referenceDate, fam.globalInflation, fam.globalReturn);
    final remainingMonths = goal.getRemainingMonths(fam.referenceDate);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      goal.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        goal.account,
                        style: const TextStyle(
                            fontSize: 10,
                            color: Colors.indigo,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              _buildGoalHealthBadge(health),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (progress / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                health == GoalHealth.onTrack
                    ? kMoneyGreen
                    : health == GoalHealth.needsAttention
                        ? const Color(0xFFD97706)
                        : Colors.redAccent,
              ),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_currencyFormatter.format(goal.currentSavings)} / ${_currencyFormatter.format(target)} (${progress.toStringAsFixed(0)}%)',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
              ),
              Text(
                '${remainingMonths}m left • Req SIP: ${_currencyFormatter.format(sip)}/mo',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: sip > 0 ? const Color(0xFF2563EB) : kMoneyGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalHealthBadge(GoalHealth health) {
    Color color;
    String label;
    switch (health) {
      case GoalHealth.onTrack:
        color = kMoneyGreen;
        label = 'On Track';
        break;
      case GoalHealth.needsAttention:
        color = const Color(0xFFD97706);
        label = 'Attention';
        break;
      case GoalHealth.behindSchedule:
        color = Colors.redAccent;
        label = 'Behind';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: FINANCIAL ENGINE DEFAULTS
  // ---------------------------------------------------------------------------
  Widget _buildFinancialEngineTab(
      AdminProvider adminProvider, GoalProvider goalProvider) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildInfoBanner(
          'Financial Engine defaults configure the baseline math for inflation projections, expected investment returns, and default dates applied across all goals.',
        ),
        const SizedBox(height: 16),

        _buildSectionCard(
          title: 'Macro-Economic & Return Benchmarks',
          children: [
            // Default Inflation
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Default Annual Inflation Rate',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: kMoneyGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_inflation.toStringAsFixed(1)} %',
                        style: const TextStyle(
                          color: kMoneyGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _inflation,
                  min: 2.0,
                  max: 12.0,
                  divisions: 20,
                  activeColor: kMoneyGreen,
                  onChanged: (val) => setState(() => _inflation = val),
                ),
                const Text(
                  'Standard Indian CPI expectation is ~6.0%. Higher rates increase future target amounts.',
                  style: TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ],
            ),
            const Divider(height: 32),

            // Default Expected Return
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Default Expected Equity/Portfolio Return (CAGR)',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_expectedReturn.toStringAsFixed(1)} %',
                        style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _expectedReturn,
                  min: 6.0,
                  max: 20.0,
                  divisions: 28,
                  activeColor: const Color(0xFF2563EB),
                  onChanged: (val) => setState(() => _expectedReturn = val),
                ),
                const Text(
                  'Default LifeGoal spreadsheet model expects 14.0% annualized long-term return for diversified equity funds.',
                  style: TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        _buildSectionCard(
          title: 'Planning Anchors & Currency',
          children: [
            // Reference Planning Date
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.calendar_today, color: Colors.purple, size: 20),
              ),
              title: const Text('Reference Planning Date',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text(
                DateFormat('dd MMMM yyyy').format(_planningDate),
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
              trailing: OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _planningDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2040),
                  );
                  if (picked != null) {
                    setState(() => _planningDate = picked);
                  }
                },
                child: const Text('Change Date'),
              ),
            ),
            const Divider(height: 24),

            // Currency Symbol
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Base Currency Symbol',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text('Select primary currency symbol for portfolio displays',
                        style: TextStyle(color: Colors.black45, fontSize: 12)),
                  ],
                ),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: '₹', label: Text('₹ INR')),
                    ButtonSegment(value: r'$', label: Text(r'$ USD')),
                    ButtonSegment(value: '€', label: Text('€ EUR')),
                  ],
                  selected: {_currency},
                  onSelectionChanged: (val) {
                    setState(() => _currency = val.first);
                  },
                ),
              ],
            ),
            const Divider(height: 24),

            // Emergency Fund Months
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Emergency Fund Buffer Default',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text('Default months of expenses needed for safety reserves',
                        style: TextStyle(color: Colors.black45, fontSize: 12)),
                  ],
                ),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 3, label: Text('3 Mo')),
                    ButtonSegment(value: 6, label: Text('6 Mo')),
                    ButtonSegment(value: 12, label: Text('12 Mo')),
                  ],
                  selected: {_emergencyMonths},
                  onSelectionChanged: (val) {
                    setState(() => _emergencyMonths = val.first);
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Quick Apply Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: kMoneyGreen,
              side: const BorderSide(color: kMoneyGreen, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              await adminProvider.saveConfig(_buildCurrentConfig(adminProvider.config));
              await adminProvider.applyDefaultsToFamily(goalProvider);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: kMoneyGreen,
                    content: Text(
                      'Applied defaults (${_inflation.toStringAsFixed(1)}% inf / ${_expectedReturn.toStringAsFixed(1)}% return) to active family portfolio!',
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.sync),
            label: const Text('Apply System Defaults to Current Active Family',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: AI & NOTIFICATIONS
  // ---------------------------------------------------------------------------
  Widget _buildAiNotificationTab(
      AdminProvider adminProvider, GoalProvider goalProvider) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildInfoBanner(
          'Configure AI notification providers, model identifiers, secret overrides, advisor tone, and test real-time AI recommendation generation.',
        ),
        const SizedBox(height: 16),

        _buildSectionCard(
          title: 'AI Model & Provider Architecture',
          children: [
            // Provider Selection
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI Provider Engine',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text('Select backend provider for intelligence generation',
                        style: TextStyle(color: Colors.black45, fontSize: 12)),
                  ],
                ),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'openrouter', label: Text('OpenRouter')),
                    ButtonSegment(value: 'local', label: Text('Local Mock')),
                    ButtonSegment(value: 'gemini', label: Text('Gemini API')),
                  ],
                  selected: {_aiProvider},
                  onSelectionChanged: (val) {
                    setState(() => _aiProvider = val.first);
                  },
                ),
              ],
            ),
            const Divider(height: 24),

            // AI Model ID
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Model Identifier',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                const Text('Specify OpenRouter or LLM model endpoint name',
                    style: TextStyle(color: Colors.black45, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildModelChip('google/gemini-2.5-flash'),
                    _buildModelChip('google/gemini-2.5-pro'),
                    _buildModelChip('anthropic/claude-3.5-sonnet'),
                    _buildModelChip('meta-llama/llama-3.3-70b-instruct'),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),

            // Custom OpenRouter Key Override
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                labelText: 'OpenRouter API Key Override (Optional)',
                hintText: 'sk-or-v1-... (leave blank to use Cloud Function secret)',
                prefixIcon: const Icon(Icons.key, color: Colors.blueAccent),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'If the Cloud Function secret has expired or thrown 401, entering a valid key here can be used for debugging or direct calls.',
              style: TextStyle(fontSize: 12, color: Colors.black45),
            ),
            const Divider(height: 24),

            // Force Local AI Fallback Switch
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Force Local AI Fallback',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text(
                'Immediately use deterministic rule-based generator without contacting external APIs (ideal for offline or when OpenRouter returns 401).',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
              value: _forceLocalAI,
              activeTrackColor: kMoneyGreen,
              onChanged: (val) => setState(() => _forceLocalAI = val),
            ),
          ],
        ),
        const SizedBox(height: 16),

        _buildSectionCard(
          title: 'Advisor Tone & Automation Schedule',
          children: [
            // AI Tone
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Advisor Persona & Tone',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text('Sets the style of AI suggestions generated',
                        style: TextStyle(color: Colors.black45, fontSize: 12)),
                  ],
                ),
                DropdownButton<String>(
                  value: _aiAdvisorTone,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(
                        value: 'balanced', child: Text('Balanced & Motivational')),
                    DropdownMenuItem(
                        value: 'conservative', child: Text('Strict & Conservative')),
                    DropdownMenuItem(
                        value: 'growth', child: Text('Aggressive Wealth Builder')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _aiAdvisorTone = val);
                  },
                ),
              ],
            ),
            const Divider(height: 24),

            // Scheduled Hour
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily Trigger Schedule',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text('Time when daily check-in recommendations are dispatched',
                        style: TextStyle(color: Colors.black45, fontSize: 12)),
                  ],
                ),
                TextButton.icon(
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                          hour: _scheduledHour, minute: _scheduledMinute),
                    );
                    if (time != null) {
                      setState(() {
                        _scheduledHour = time.hour;
                        _scheduledMinute = time.minute;
                      });
                    }
                  },
                  icon: const Icon(Icons.access_time, color: kMoneyGreen),
                  label: Text(
                    '${_scheduledHour.toString().padLeft(2, '0')}:${_scheduledMinute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: kMoneyGreen),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-Trigger Scheduled Notifications',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text(
                'Automatically execute recommendation generation at scheduled daily time',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
              value: _autoNotifications,
              activeTrackColor: kMoneyGreen,
              onChanged: (val) => setState(() => _autoNotifications = val),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Live Test Generator Card
        _buildSectionCard(
          title: 'Interactive AI Generation Test',
          children: [
            const Text(
              'Test notification generation live using current portfolio data and selected AI configuration.',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _isTestingAi
                    ? null
                    : () async {
                        setState(() => _isTestingAi = true);
                        try {
                          // Temporary apply local state into provider
                          adminProvider.updateInMemory(
                              _buildCurrentConfig(adminProvider.config));
                          final note =
                              await adminProvider.testAiNotification(goalProvider);
                          setState(() {
                            _testedNotification = note;
                          });
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Test AI error: $e')),
                            );
                          }
                        } finally {
                          setState(() => _isTestingAi = false);
                        }
                      },
                icon: _isTestingAi
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text(
                  _isTestingAi ? 'Running AI Generator...' : 'Execute Test AI Generation',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (_testedNotification != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueGrey.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_outline,
                            color: kMoneyGreen, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _testedNotification!.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _testedNotification!.trigger.name,
                            style: const TextStyle(
                                fontSize: 10,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _testedNotification!.body,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black87, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.touch_app_outlined,
                              size: 16, color: kMoneyGreen),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _testedNotification!.suggestedAction,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildModelChip(String modelName) {
    final isSelected = _aiModel == modelName;
    return ChoiceChip(
      label: Text(modelName, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      selectedColor: kMoneyGreen.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? kMoneyGreen : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => setState(() => _aiModel = modelName),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 4: FEATURE FLAGS & SECURITY
  // ---------------------------------------------------------------------------
  Widget _buildFeatureFlagsTab(AdminProvider adminProvider) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildInfoBanner(
          'Platform Feature Flags control live availability of modules, maintenance lockouts, and super administrator access security.',
        ),
        const SizedBox(height: 16),

        _buildSectionCard(
          title: 'System Access & Availability Flags',
          children: [
            // Maintenance Mode
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Maintenance Mode',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text(
                'When enabled, displays a system maintenance alert to non-admin users.',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
              value: _maintenanceMode,
              activeTrackColor: Colors.redAccent,
              onChanged: (val) => setState(() => _maintenanceMode = val),
            ),
            if (_maintenanceMode) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _maintenanceMsgController,
                decoration: InputDecoration(
                  labelText: 'Maintenance Banner Message',
                  filled: true,
                  fillColor: const Color(0xFFFEF2F2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.redAccent),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const Divider(height: 24),

            // Allow Registrations
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow New Family Registrations',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text(
                'Toggle public registration vs invite-only access mode.',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
              value: _allowRegistrations,
              activeTrackColor: kMoneyGreen,
              onChanged: (val) => setState(() => _allowRegistrations = val),
            ),
            const Divider(height: 24),

            // PWA Banner
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('PWA Installation Banner',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text(
                'Show "Install LifeGoal App" top banner on compatible mobile browsers.',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
              value: _pwaBanner,
              activeTrackColor: kMoneyGreen,
              onChanged: (val) => setState(() => _pwaBanner = val),
            ),
            const Divider(height: 24),

            // Scenario Simulator
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Scenario Simulator (Experimental)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text(
                'Enable what-if scenario simulator sandbox in goal detail screens.',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
              value: _scenarioSimulator,
              activeTrackColor: kMoneyGreen,
              onChanged: (val) => setState(() => _scenarioSimulator = val),
            ),
            const Divider(height: 24),

            // Strict Goal Deletion
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Strict Goal Deletion Control',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text(
                'Restrict deleting goals to the primary Family Admin only.',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
              value: _strictGoalDelete,
              activeTrackColor: kMoneyGreen,
              onChanged: (val) => setState(() => _strictGoalDelete = val),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Security Configuration
        _buildSectionCard(
          title: 'Super Admin Security & Access Whitelist',
          children: [
            // PIN field
            TextField(
              controller: _newPinController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Change Super Admin Security PIN',
                hintText: 'e.g. 7788',
                prefixIcon: const Icon(Icons.password, color: kMoneyGreen),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
            const Divider(height: 32),

            // Whitelisted Emails
            const Text(
              'Authorized Super Admin Emails',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              'Users with these email addresses bypass the PIN prompt upon sign-in.',
              style: TextStyle(color: Colors.black45, fontSize: 12),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _adminEmails.map((email) {
                return Chip(
                  avatar: const Icon(Icons.verified_user, size: 16, color: kMoneyGreen),
                  label: Text(email),
                  backgroundColor: kMoneyGreen.withValues(alpha: 0.08),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: _adminEmails.length > 1
                      ? () => setState(() => _adminEmails.remove(email))
                      : null,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newEmailController,
                    decoration: InputDecoration(
                      hintText: 'Add authorized email (e.g. admin@domain.com)',
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kMoneyGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    final email = _newEmailController.text.trim().toLowerCase();
                    if (email.contains('@') && !_adminEmails.contains(email)) {
                      setState(() {
                        _adminEmails.add(email);
                        _newEmailController.clear();
                      });
                    }
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 5: DATA MANAGEMENT & BACKUP TOOLS
  // ---------------------------------------------------------------------------
  Widget _buildDataToolsTab(
      AdminProvider adminProvider, GoalProvider goalProvider) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildInfoBanner(
          'Backup configuration, restore from JSON presets, seed template spreadsheet goals, or manage platform test data.',
        ),
        const SizedBox(height: 16),

        _buildSectionCard(
          title: 'Template Goals Seeding',
          children: [
            const Text(
              'Inject the standard 7 spreadsheet benchmark goals (Dream Home, Bali Vacation, Children Education, Marriage, Home Loan, Emergency) into the current family portfolio.',
              style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kMoneyGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _confirmReimportSpreadsheet(goalProvider),
                icon: const Icon(Icons.table_chart_outlined, size: 20),
                label: const Text('Re-seed Default Spreadsheet Goals',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        _buildSectionCard(
          title: 'Configuration Backup & Restore',
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      final json = adminProvider.exportToJson();
                      Clipboard.setData(ClipboardData(text: json));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Configuration JSON copied to clipboard!'),
                          backgroundColor: kMoneyGreen,
                        ),
                      );
                      _showExportDialog(json);
                    },
                    icon: const Icon(Icons.copy_all),
                    label: const Text('Export JSON'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _showImportDialog(adminProvider),
                    icon: const Icon(Icons.file_download_outlined),
                    label: const Text('Import JSON'),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Cache & Session Reset
        _buildSectionCard(
          title: 'Cache & Session Management',
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lock_clock, color: Colors.amber, size: 20),
              ),
              title: const Text('Lock Super Admin Session',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text(
                  'Locks access and requires re-entering the security PIN on return',
                  style: TextStyle(color: Colors.black45, fontSize: 12)),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                onPressed: () {
                  adminProvider.lockSession();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Admin session locked.')),
                  );
                },
                child: const Text('Lock Now'),
              ),
            ),
            const Divider(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_sweep_outlined,
                    color: Colors.redAccent, size: 20),
              ),
              title: const Text('Reset All Settings to Factory Defaults',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.redAccent)),
              subtitle: const Text(
                  'Restore original baseline values across all 5 admin modules',
                  style: TextStyle(color: Colors.black45, fontSize: 12)),
              trailing: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                ),
                onPressed: () => _confirmReset(adminProvider),
                child: const Text('Factory Reset'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // HELPER WIDGETS & DIALOGS
  // ---------------------------------------------------------------------------
  Widget _buildSectionCard({
    String? title,
    required List<Widget> children,
  }) {
    return Material(
      color: kCardBg,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),
            ],
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kMoneyGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kMoneyGreen.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: kMoneyGreen, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.black45),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
              fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmReset(AdminProvider adminProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Factory Defaults?'),
        content: const Text(
          'This will reset all Super Admin configurations (inflation, returns, AI models, feature flags) back to system default values.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await adminProvider.resetToDefaults();
      _syncFromConfig(adminProvider.config);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration reset to defaults.'),
            backgroundColor: kMoneyGreen,
          ),
        );
      }
    }
  }

  Future<void> _confirmReimportSpreadsheet(GoalProvider goalProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Re-seed Spreadsheet Goals?'),
        content: const Text(
          'This will import/refresh the 7 standard benchmark goals into the current family. Existing recorded savings history will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kMoneyGreen),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import Goals', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final count = await goalProvider.importSpreadsheetGoals();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully refreshed $count benchmark goals!'),
              backgroundColor: kMoneyGreen,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error importing goals: $e')),
          );
        }
      }
    }
  }

  void _showExportDialog(String jsonStr) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exported Super Admin Configuration'),
        content: SingleChildScrollView(
          child: SelectableText(
            jsonStr,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: kMoneyGreen),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonStr));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard!')),
              );
            },
            icon: const Icon(Icons.copy, size: 16, color: Colors.white),
            label: const Text('Copy to Clipboard',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(AdminProvider adminProvider) {
    final importController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Import Configuration JSON'),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: importController,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: 'Paste configuration JSON here...',
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kMoneyGreen),
            onPressed: () async {
              final text = importController.text.trim();
              if (text.isNotEmpty) {
                final success = await adminProvider.importFromJson(text);
                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                }
                if (mounted) {
                  if (success) {
                    _syncFromConfig(adminProvider.config);
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Configuration imported successfully!'),
                        backgroundColor: kMoneyGreen,
                      ),
                    );
                  } else {
                    messenger.showSnackBar(
                      SnackBar(content: Text(adminProvider.lastError ?? 'Invalid JSON format')),
                    );
                  }
                }
              }
            },
            child: const Text('Import & Apply', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
