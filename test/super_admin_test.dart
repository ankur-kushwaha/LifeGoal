import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lifegoal_app/models/admin_config_model.dart';
import 'package:lifegoal_app/models/family_model.dart';
import 'package:lifegoal_app/models/goal_model.dart';
import 'package:lifegoal_app/models/profile_model.dart';
import 'package:lifegoal_app/providers/admin_provider.dart';
import 'package:lifegoal_app/providers/goal_provider.dart';
import 'package:lifegoal_app/screens/super_admin_screen.dart';
import 'package:lifegoal_app/services/admin_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AdminConfig Model Tests', () {
    test('Default values are initialized properly', () {
      final config = AdminConfig.defaultValues();
      expect(config.defaultInflationRate, 6.0);
      expect(config.defaultExpectedReturn, 14.0);
      expect(config.currencySymbol, '₹');
      expect(config.adminPin, '7788');
      expect(config.aiProvider, 'openrouter');
      expect(config.aiModel, 'google/gemini-2.5-flash');
      expect(config.scheduledNotificationHour, 10);
      expect(config.scheduledNotificationMinute, 0);
      expect(config.superAdminEmails.contains('ankur@lifegoal.ai'), isTrue);
    });

    test('Serialization and deserialization match (toJson / fromJson)', () {
      final original = AdminConfig(
        defaultInflationRate: 7.5,
        defaultExpectedReturn: 15.0,
        defaultPlanningDate: DateTime(2027, 1, 1),
        currencySymbol: r'$',
        emergencyFundMonthsDefault: 12,
        safeWithdrawalRate: 3.5,
        aiProvider: 'gemini',
        aiModel: 'google/gemini-2.5-pro',
        scheduledNotificationHour: 9,
        scheduledNotificationMinute: 30,
        aiAdvisorTone: 'growth',
        autoNotificationsEnabled: false,
        forceLocalAIFallback: true,
        customOpenRouterApiKey: 'sk-test-key-12345',
        maintenanceMode: true,
        maintenanceMessage: 'System upgrading',
        allowNewRegistrations: false,
        pwaPromptEnabled: false,
        scenarioSimulatorEnabled: true,
        strictAdminOnlyGoalDelete: true,
        analyticsTrackingEnabled: false,
        superAdminEmails: const ['owner@custom.com', 'admin@custom.com'],
        adminPin: '9988',
        pinProtectionEnabled: true,
        lastUpdated: DateTime(2026, 8, 15),
        updatedBy: 'Test Admin',
      );

      final jsonMap = original.toJson();
      final reconstituted = AdminConfig.fromJson(jsonMap);

      expect(reconstituted.defaultInflationRate, 7.5);
      expect(reconstituted.defaultExpectedReturn, 15.0);
      expect(reconstituted.currencySymbol, r'$');
      expect(reconstituted.emergencyFundMonthsDefault, 12);
      expect(reconstituted.safeWithdrawalRate, 3.5);
      expect(reconstituted.aiProvider, 'gemini');
      expect(reconstituted.aiModel, 'google/gemini-2.5-pro');
      expect(reconstituted.scheduledNotificationHour, 9);
      expect(reconstituted.scheduledNotificationMinute, 30);
      expect(reconstituted.aiAdvisorTone, 'growth');
      expect(reconstituted.autoNotificationsEnabled, isFalse);
      expect(reconstituted.forceLocalAIFallback, isTrue);
      expect(reconstituted.customOpenRouterApiKey, 'sk-test-key-12345');
      expect(reconstituted.maintenanceMode, isTrue);
      expect(reconstituted.maintenanceMessage, 'System upgrading');
      expect(reconstituted.allowNewRegistrations, isFalse);
      expect(reconstituted.pwaPromptEnabled, isFalse);
      expect(reconstituted.scenarioSimulatorEnabled, isTrue);
      expect(reconstituted.strictAdminOnlyGoalDelete, isTrue);
      expect(reconstituted.analyticsTrackingEnabled, isFalse);
      expect(reconstituted.adminPin, '9988');
      expect(reconstituted.superAdminEmails, contains('owner@custom.com'));
    });

    test('toFormattedJson produces valid pretty JSON', () {
      final config = AdminConfig.defaultValues();
      final pretty = config.toFormattedJson();
      final decoded = json.decode(pretty) as Map<String, dynamic>;
      expect(decoded['defaultInflationRate'], 6.0);
      expect(decoded['currencySymbol'], '₹');
    });
  });

  group('AdminService Tests', () {
    test('isAuthorizedSuperAdmin verifies correct PIN and emails', () {
      final service = AdminService();

      // PIN check
      expect(service.isAuthorizedSuperAdmin(enteredPin: '7788'), isTrue);
      expect(service.isAuthorizedSuperAdmin(enteredPin: '0000'), isFalse);

      // Email check
      expect(
          service.isAuthorizedSuperAdmin(email: 'ankur@lifegoal.ai'), isTrue);
      expect(
          service.isAuthorizedSuperAdmin(email: 'admin@lifegoal.ai'), isTrue);
      expect(
          service.isAuthorizedSuperAdmin(email: 'random@other.com'), isFalse);
    });

    test('saveConfig and loadConfig round trip through SharedPreferences',
        () async {
      final service = AdminService();
      final initial = await service.loadConfig();

      final updated = initial.copyWith(
        defaultInflationRate: 8.0,
        defaultExpectedReturn: 16.0,
        adminPin: '4321',
      );

      await service.saveConfig(updated);
      final reloaded = await service.loadConfig();

      expect(reloaded.defaultInflationRate, 8.0);
      expect(reloaded.defaultExpectedReturn, 16.0);
      expect(reloaded.adminPin, '4321');
    });

    test('resetDefaults restores initial defaults', () async {
      final service = AdminService();
      await service.saveConfig(AdminConfig.defaultValues().copyWith(
        defaultInflationRate: 10.0,
      ));

      final reset = await service.resetDefaults();
      expect(reset.defaultInflationRate, 6.0);
      expect(reset.defaultExpectedReturn, 14.0);
    });
  });

  group('AdminProvider Tests', () {
    test('verifyPin unlocks admin session', () async {
      final provider = AdminProvider();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(provider.isSuperAdminVerified, isFalse);
      final ok = provider.verifyPin('7788');
      expect(ok, isTrue);
      expect(provider.isSuperAdminVerified, isTrue);

      provider.lockSession();
      expect(provider.isSuperAdminVerified, isFalse);
    });

    test('applyDefaultsToFamily updates GoalProvider settings', () async {
      final adminProvider = AdminProvider();
      final goal = GoalModel(
        id: 'test-goal',
        name: 'Retirement Fund',
        account: 'Ankur',
        targetCost: 10000000,
        startDate: DateTime(2024, 1, 1),
        targetDate: DateTime(2045, 1, 1),
        currentSavings: 1500000,
      );

      final goalProvider = GoalProvider.forTesting(
        goals: [goal],
        globalInflation: 5.0,
        globalReturn: 12.0,
        today: DateTime(2025, 1, 1),
      );

      adminProvider.updateInMemory(adminProvider.config.copyWith(
        defaultInflationRate: 7.0,
        defaultExpectedReturn: 15.0,
        defaultPlanningDate: DateTime(2026, 7, 1),
      ));

      await adminProvider.applyDefaultsToFamily(goalProvider);

      expect(goalProvider.globalInflation, 7.0);
      expect(goalProvider.globalReturn, 15.0);
      expect(goalProvider.today, DateTime(2026, 7, 1));
    });

    test('deleteFamily removes family from in-memory list and storage', () async {
      final adminProvider = AdminProvider();
      final goalProvider = GoalProvider.forTesting();

      // Pre-load families
      await adminProvider.fetchAllFamilies(goalProvider);

      if (adminProvider.allFamilies.isNotEmpty) {
        final targetId = adminProvider.allFamilies.first.family.id;
        final initialCount = adminProvider.allFamilies.length;

        final success = await adminProvider.deleteFamily(targetId, goalProvider);

        expect(success, isTrue);
        expect(adminProvider.allFamilies.any((f) => f.family.id == targetId), isFalse);
        expect(adminProvider.allFamilies.length, initialCount - 1);
      }
    });

    test('addMemberToFamily, updateFamilyMember, and removeMemberFromFamily manage family members', () async {
      final adminProvider = AdminProvider();
      final goalProvider = GoalProvider.forTesting();

      // Ensure mock family exists in storage
      final prefs = await SharedPreferences.getInstance();
      const famId = 'fam-test-123';
      final family = FamilyInfo(
        id: famId,
        name: 'Test Family',
        adminId: 'admin-1',
        createdAt: DateTime(2025, 1, 1),
      );
      await prefs.setString('family_$famId', json.encode(family.toJson()));
      await prefs.setString('members_$famId', json.encode([
        {
          'userId': 'admin-1',
          'email': 'admin@test.com',
          'displayName': 'Admin One',
          'role': 'admin',
          'joinedAt': DateTime(2025, 1, 1).toIso8601String(),
        }
      ]));

      await adminProvider.fetchAllFamilies(goalProvider);
      expect(adminProvider.allFamilies.any((f) => f.family.id == famId), isTrue);

      // 1. Add member
      final addOk = await adminProvider.addMemberToFamily(
        famId,
        email: 'newuser@test.com',
        displayName: 'New Member',
        role: FamilyRole.member,
        memberProfile: const MemberProfile(
          employmentType: EmploymentType.salaried,
          monthlyIncome: 85000,
          retirementAge: 58,
        ),
      );
      expect(addOk, isTrue);

      final famAfterAdd = adminProvider.allFamilies.firstWhere((f) => f.family.id == famId);
      final added = famAfterAdd.members.firstWhere((m) => m.email == 'newuser@test.com');
      expect(added.displayName, 'New Member');
      expect(added.memberProfile.monthlyIncome, 85000);
      expect(added.memberProfile.retirementAge, 58);

      // 2. Update member
      final updateOk = await adminProvider.updateFamilyMember(
        famId,
        added.userId,
        displayName: 'Updated Member',
        role: FamilyRole.admin,
        memberProfile: added.memberProfile.copyWith(monthlyIncome: 95000),
      );
      expect(updateOk, isTrue);

      final famAfterUpdate = adminProvider.allFamilies.firstWhere((f) => f.family.id == famId);
      final updated = famAfterUpdate.members.firstWhere((m) => m.userId == added.userId);
      expect(updated.displayName, 'Updated Member');
      expect(updated.role, FamilyRole.admin);
      expect(updated.memberProfile.monthlyIncome, 95000);

      // 3. Remove member
      final removeOk = await adminProvider.removeMemberFromFamily(
        famId,
        added.userId,
      );
      expect(removeOk, isTrue);

      final famAfterRemove = adminProvider.allFamilies.firstWhere((f) => f.family.id == famId);
      expect(famAfterRemove.members.any((m) => m.userId == added.userId), isFalse);
    });
  });

  group('SuperAdminScreen Widget Tests', () {
    testWidgets('Renders PIN Lock Screen when not authenticated',
        (WidgetTester tester) async {
      final adminProvider = AdminProvider();
      final goalProvider = GoalProvider.forTesting();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AdminProvider>.value(value: adminProvider),
            ChangeNotifierProvider<GoalProvider>.value(value: goalProvider),
          ],
          child: const MaterialApp(
            home: SuperAdminScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Super Admin Access'), findsOneWidget);
      expect(find.text('Admin Security PIN'), findsOneWidget);
      expect(find.text('Unlock Console'), findsOneWidget);
      expect(find.text('Developer One-Click Unlock'), findsOneWidget);
    });

    testWidgets('Unlocking console reveals all 6 tabs and configuration items including All Families',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final adminProvider = AdminProvider();
      final goal = GoalModel(
        id: 'g1',
        name: 'Emergency Fund',
        account: 'Ankur',
        targetCost: 500000,
        startDate: DateTime(2024, 1, 1),
        targetDate: DateTime(2026, 12, 31),
        currentSavings: 400000,
      );

      final goalProvider = GoalProvider.forTesting(
        goals: [goal],
      );

      // Pre-authorize admin
      adminProvider.grantAccessForTesting();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AdminProvider>.value(value: adminProvider),
            ChangeNotifierProvider<GoalProvider>.value(value: goalProvider),
          ],
          child: const MaterialApp(
            home: SuperAdminScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Top bar & buttons
      expect(find.text('Super Admin View'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);

      // 6 Tabs
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('All Families'), findsOneWidget);
      expect(find.text('Financial Engine'), findsOneWidget);
      expect(find.text('AI & Notifications'), findsOneWidget);
      expect(find.text('Feature Flags'), findsOneWidget);
      expect(find.text('Data Tools'), findsOneWidget);

      // Overview content
      expect(find.text('Platform Metrics'), findsOneWidget);
      expect(find.text('Total Tracked Corpus'), findsOneWidget);
      expect(find.text('Active Goals'), findsOneWidget);

      // Tap All Families tab
      await tester.tap(find.text('All Families'));
      await tester.pumpAndSettle();

      expect(find.text('Multi-tenant view: Inspect all registered families, their members, roles, and tracked goals across the entire system.'), findsOneWidget);
      expect(find.text('Refresh Families'), findsOneWidget);

      // Tap Financial Engine tab
      await tester.tap(find.text('Financial Engine'));
      await tester.pumpAndSettle();

      expect(find.text('Macro-Economic & Return Benchmarks'), findsOneWidget);
      expect(find.text('Default Annual Inflation Rate'), findsOneWidget);
      expect(find.text('Default Expected Equity/Portfolio Return (CAGR)'),
          findsOneWidget);
      expect(find.text('Apply System Defaults to Current Active Family'),
          findsOneWidget);

      // Tap AI & Notifications tab
      await tester.tap(find.text('AI & Notifications'));
      await tester.pumpAndSettle();

      expect(find.text('AI Model & Provider Architecture'), findsOneWidget);
      expect(find.text('Force Local AI Fallback'), findsOneWidget);
      expect(find.text('Execute Test AI Generation'), findsOneWidget);

      // Tap Feature Flags tab
      await tester.tap(find.text('Feature Flags'));
      await tester.pumpAndSettle();

      expect(find.text('System Access & Availability Flags'), findsOneWidget);
      expect(find.text('Maintenance Mode'), findsOneWidget);
      expect(find.text('Allow New Family Registrations'), findsOneWidget);
      expect(find.text('Authorized Super Admin Emails'), findsOneWidget);

      // Tap Data Tools tab
      await tester.tap(find.text('Data Tools'));
      await tester.pumpAndSettle();

      expect(find.text('Template Goals Seeding'), findsOneWidget);
      expect(find.text('Re-seed Default Spreadsheet Goals'), findsOneWidget);
      expect(find.text('Export JSON'), findsOneWidget);
      expect(find.text('Import JSON'), findsOneWidget);
      expect(find.text('Lock Super Admin Session'), findsOneWidget);
    });
  });
}
