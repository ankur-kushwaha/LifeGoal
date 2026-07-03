import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../models/profile_model.dart';
import '../providers/goal_provider.dart';
import 'member_profile_screen.dart';

class FamilyProfileScreen extends StatefulWidget {
  const FamilyProfileScreen({super.key});

  @override
  State<FamilyProfileScreen> createState() => _FamilyProfileScreenState();
}

class _FamilyProfileScreenState extends State<FamilyProfileScreen> {
  final _incomeController = TextEditingController();
  final _expensesController = TextEditingController();
  bool _initialized = false;
  bool _isSaving = false;
  String? _error;
  String? _success;

  late FamilyProfile _profile;

  @override
  void dispose() {
    _incomeController.dispose();
    _expensesController.dispose();
    super.dispose();
  }

  void _initFromProvider(GoalProvider provider) {
    if (_initialized) return;
    _profile = provider.familyProfile;
    _incomeController.text = _formatAmount(_profile.monthlyHouseholdIncome);
    _expensesController.text = _formatAmount(_profile.monthlyHouseholdExpenses);
    _initialized = true;
  }

  String _formatAmount(double? value) {
    if (value == null) return '';
    return NumberFormat.decimalPattern('en_IN').format(value.round());
  }

  double? _parseAmount(String text) {
    final cleaned = text.replaceAll(',', '').trim();
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  Future<void> _save(GoalProvider provider) async {
    setState(() {
      _isSaving = true;
      _error = null;
      _success = null;
    });

    try {
      final updated = _profile.copyWith(
        monthlyHouseholdIncome: _parseAmount(_incomeController.text),
        monthlyHouseholdExpenses: _parseAmount(_expensesController.text),
      );
      await provider.saveFamilyProfile(updated);
      setState(() {
        _profile = updated;
        _success = 'Profile saved';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GoalProvider>();
    _initFromProvider(provider);
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: kScaffoldBg,
      appBar: AppBar(
        backgroundColor: kCardBg,
        title: const Text('Family Profile', style: TextStyle(color: Colors.black87)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) _banner(_error!, Colors.redAccent),
          if (_success != null) _banner(_success!, kMoneyGreen),
          _sectionTitle('Household finances'),
          _card([
            _amountField('Monthly household income', _incomeController),
            const SizedBox(height: 12),
            _amountField('Monthly household expenses', _expensesController),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _profile.emergencyFundMonths,
              decoration: _inputDecoration('Emergency fund target'),
              items: const [
                DropdownMenuItem(value: 3, child: Text('3 months of expenses')),
                DropdownMenuItem(value: 6, child: Text('6 months of expenses')),
                DropdownMenuItem(value: 12, child: Text('12 months of expenses')),
              ],
              onChanged: (v) => setState(() => _profile = _profile.copyWith(emergencyFundMonths: v ?? 6)),
            ),
            if (_profile.emergencyFundTarget != null) ...[
              const SizedBox(height: 8),
              Text(
                'Target: ${currency.format(_profile.emergencyFundTarget)}',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
            ],
            if (_profile.monthlySurplus != null) ...[
              const SizedBox(height: 8),
              Text(
                'Est. monthly surplus after expenses & EMIs: ${currency.format(_profile.monthlySurplus)}',
                style: const TextStyle(color: kMoneyGreen, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ]),
          const SizedBox(height: 20),
          _sectionTitle('Housing & insurance'),
          _card([
            DropdownButtonFormField<HousingStatus>(
              value: _profile.housingStatus,
              decoration: _inputDecoration('Housing status'),
              items: HousingStatus.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                  .toList(),
              onChanged: (v) => setState(
                () => _profile = _profile.copyWith(housingStatus: v ?? HousingStatus.rent),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Health insurance', style: TextStyle(color: Colors.black87)),
              value: _profile.hasHealthInsurance,
              activeThumbColor: kMoneyGreen,
              onChanged: (v) => setState(() => _profile = _profile.copyWith(hasHealthInsurance: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Life insurance', style: TextStyle(color: Colors.black87)),
              value: _profile.hasLifeInsurance,
              activeThumbColor: kMoneyGreen,
              onChanged: (v) => setState(() => _profile = _profile.copyWith(hasLifeInsurance: v)),
            ),
          ]),
          const SizedBox(height: 20),
          _sectionTitle('Dependents (kids & family)'),
          ..._profile.dependents.map(_dependentTile),
          TextButton.icon(
            onPressed: _addDependent,
            icon: const Icon(Icons.add, color: kMoneyGreen),
            label: const Text('Add dependent', style: TextStyle(color: kMoneyGreen)),
          ),
          const SizedBox(height: 20),
          _sectionTitle('Loans & EMIs'),
          ..._profile.loans.map(_loanTile),
          TextButton.icon(
            onPressed: _addLoan,
            icon: const Icon(Icons.add, color: kMoneyGreen),
            label: const Text('Add loan', style: TextStyle(color: kMoneyGreen)),
          ),
          const SizedBox(height: 20),
          _sectionTitle('Member profiles'),
          ...provider.familyMembers.map((member) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(member.label, style: const TextStyle(color: Colors.black87)),
                subtitle: Text(
                  member.memberProfile.isEmpty
                      ? 'Not filled in'
                      : [
                          if (member.memberProfile.ageYears != null)
                            'Age ${member.memberProfile.ageYears}',
                          if (member.memberProfile.monthlyIncome != null)
                            'Income ${currency.format(member.memberProfile.monthlyIncome)}',
                        ].join(' · '),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.black38),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MemberProfileScreen(member: member),
                    ),
                  );
                  setState(() => _initialized = false);
                },
              )),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isSaving ? null : () => _save(provider),
            style: FilledButton.styleFrom(
              backgroundColor: kMoneyGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save family profile'),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(color: kMoneyGreen, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.black54),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _amountField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,]'))],
      decoration: _inputDecoration(label),
    );
  }

  Widget _banner(String message, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: TextStyle(color: color)),
    );
  }

  Widget _dependentTile(Dependent dep) {
    final age = dep.ageYears;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(dep.name),
        subtitle: Text('${dep.relationship.label}${age != null ? ' · age $age' : ''}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: () => setState(() {
            _profile = _profile.copyWith(
              dependents: _profile.dependents.where((d) => d.id != dep.id).toList(),
            );
          }),
        ),
        onTap: () => _editDependent(dep),
      ),
    );
  }

  Widget _loanTile(FamilyLoan loan) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(loan.type.label),
        subtitle: Text(
          'EMI ₹${NumberFormat.decimalPattern('en_IN').format(loan.emi.round())} · ${loan.remainingMonths} mo left',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: () => setState(() {
            _profile = _profile.copyWith(
              loans: _profile.loans.where((l) => l.id != loan.id).toList(),
            );
          }),
        ),
        onTap: () => _editLoan(loan),
      ),
    );
  }

  Future<void> _addDependent() async {
    final dep = await _showDependentDialog();
    if (dep != null) {
      setState(() => _profile = _profile.copyWith(dependents: [..._profile.dependents, dep]));
    }
  }

  Future<void> _editDependent(Dependent dep) async {
    final updated = await _showDependentDialog(existing: dep);
    if (updated != null) {
      setState(() {
        _profile = _profile.copyWith(
          dependents: _profile.dependents.map((d) => d.id == dep.id ? updated : d).toList(),
        );
      });
    }
  }

  Future<void> _addLoan() async {
    final loan = await _showLoanDialog();
    if (loan != null) {
      setState(() => _profile = _profile.copyWith(loans: [..._profile.loans, loan]));
    }
  }

  Future<void> _editLoan(FamilyLoan loan) async {
    final updated = await _showLoanDialog(existing: loan);
    if (updated != null) {
      setState(() {
        _profile = _profile.copyWith(
          loans: _profile.loans.map((l) => l.id == loan.id ? updated : l).toList(),
        );
      });
    }
  }

  Future<Dependent?> _showDependentDialog({Dependent? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    var relationship = existing?.relationship ?? DependentRelationship.child;
    DateTime? dob = existing?.dateOfBirth;

    return showDialog<Dependent>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: kCardBg,
          title: Text(existing == null ? 'Add dependent' : 'Edit dependent'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: _inputDecoration('Name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<DependentRelationship>(
                  value: relationship,
                  decoration: _inputDecoration('Relationship'),
                  items: DependentRelationship.values
                      .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => relationship = v ?? relationship),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    dob == null ? 'Date of birth' : DateFormat.yMMMd().format(dob!),
                    style: const TextStyle(color: Colors.black87),
                  ),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: dob ?? DateTime(2015),
                      firstDate: DateTime(1940),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setDialogState(() => dob = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                Navigator.pop(
                  context,
                  Dependent(
                    id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text.trim(),
                    relationship: relationship,
                    dateOfBirth: dob,
                  ),
                );
              },
              child: const Text('Save', style: TextStyle(color: kMoneyGreen)),
            ),
          ],
        ),
      ),
    );
  }

  Future<FamilyLoan?> _showLoanDialog({FamilyLoan? existing}) async {
    final emiController = TextEditingController(
      text: existing != null ? existing.emi.round().toString() : '',
    );
    final monthsController = TextEditingController(
      text: existing?.remainingMonths.toString() ?? '',
    );
    final outstandingController = TextEditingController(
      text: existing?.outstandingAmount?.round().toString() ?? '',
    );
    var type = existing?.type ?? LoanType.home;

    return showDialog<FamilyLoan>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: kCardBg,
          title: Text(existing == null ? 'Add loan' : 'Edit loan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<LoanType>(
                  value: type,
                  decoration: _inputDecoration('Loan type'),
                  items: LoanType.values
                      .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => type = v ?? type),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emiController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('Monthly EMI (₹)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: monthsController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('Months remaining'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: outstandingController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('Outstanding amount (optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                final emi = double.tryParse(emiController.text.trim());
                final months = int.tryParse(monthsController.text.trim());
                if (emi == null || months == null) return;
                Navigator.pop(
                  context,
                  FamilyLoan(
                    id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    type: type,
                    emi: emi,
                    remainingMonths: months,
                    outstandingAmount: double.tryParse(outstandingController.text.trim()),
                  ),
                );
              },
              child: const Text('Save', style: TextStyle(color: kMoneyGreen)),
            ),
          ],
        ),
      ),
    );
  }
}
