import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../models/family_model.dart';
import '../models/profile_model.dart';
import '../providers/goal_provider.dart';

class MemberProfileScreen extends StatefulWidget {
  final FamilyMember member;

  const MemberProfileScreen({super.key, required this.member});

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  late MemberProfile _profile;
  final _incomeController = TextEditingController();
  final _expensesController = TextEditingController();
  bool _isSaving = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _profile = widget.member.memberProfile;
    _incomeController.text = _formatAmount(_profile.monthlyIncome);
    _expensesController.text = _formatAmount(_profile.monthlyExpenses);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSavedProfile());
  }

  Future<void> _loadSavedProfile() async {
    if (!_profile.isEmpty) return;
    final provider = context.read<GoalProvider>();
    final saved = await provider.loadMemberProfile(widget.member.userId);
    if (!mounted || saved.isEmpty) return;
    setState(() {
      _profile = saved;
      _incomeController.text = _formatAmount(_profile.monthlyIncome);
      _expensesController.text = _formatAmount(_profile.monthlyExpenses);
    });
  }

  @override
  void dispose() {
    _incomeController.dispose();
    _expensesController.dispose();
    super.dispose();
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
        monthlyIncome: _parseAmount(_incomeController.text),
        monthlyExpenses: _parseAmount(_expensesController.text),
      );
      await provider.saveMemberProfile(widget.member.userId, updated);
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
    final canEdit = provider.currentUserId == widget.member.userId || provider.isFamilyAdmin;

    return Scaffold(
      backgroundColor: kScaffoldBg,
      appBar: AppBar(
        backgroundColor: kCardBg,
        title: Text('${widget.member.label} Profile', style: const TextStyle(color: Colors.black87)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            _banner(_error!, Colors.redAccent),
          if (_success != null)
            _banner(_success!, kMoneyGreen),
          if (!canEdit)
            _banner('Only ${widget.member.label} or the family admin can edit this profile.', Colors.orange),
          _card([
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _profile.dateOfBirth == null
                    ? 'Date of birth'
                    : DateFormat.yMMMd().format(_profile.dateOfBirth!),
                style: const TextStyle(color: Colors.black87),
              ),
              subtitle: _profile.ageYears != null ? Text('Age ${_profile.ageYears}') : null,
              trailing: canEdit ? const Icon(Icons.calendar_today, size: 18) : null,
              onTap: !canEdit
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _profile.dateOfBirth ?? DateTime(1990),
                        firstDate: DateTime(1940),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _profile = _profile.copyWith(dateOfBirth: picked));
                    },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _incomeController,
              enabled: canEdit,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,]'))],
              decoration: _inputDecoration('Monthly income (₹)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _expensesController,
              enabled: canEdit,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,]'))],
              decoration: _inputDecoration('Personal monthly expenses (₹)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<EmploymentType>(
              value: _profile.employmentType,
              decoration: _inputDecoration('Employment'),
              items: EmploymentType.values
                  .map((e) => DropdownMenuItem(value: e, child: Text(e.label)))
                  .toList(),
              onChanged: !canEdit
                  ? null
                  : (v) => setState(
                        () => _profile = _profile.copyWith(employmentType: v ?? EmploymentType.salaried),
                      ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<RiskAppetite>(
              value: _profile.riskAppetite,
              decoration: _inputDecoration('Risk appetite'),
              items: RiskAppetite.values
                  .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                  .toList(),
              onChanged: !canEdit
                  ? null
                  : (v) => setState(
                        () => _profile = _profile.copyWith(riskAppetite: v ?? RiskAppetite.moderate),
                      ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _profile.retirementAge,
              decoration: _inputDecoration('Target retirement age'),
              items: List.generate(16, (i) => 55 + i)
                  .map((age) => DropdownMenuItem(value: age, child: Text('$age years')))
                  .toList(),
              onChanged: !canEdit
                  ? null
                  : (v) => setState(() => _profile = _profile.copyWith(retirementAge: v ?? 60)),
            ),
          ]),
          if (canEdit) ...[
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
                  : const Text('Save profile'),
            ),
          ],
        ],
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
}
