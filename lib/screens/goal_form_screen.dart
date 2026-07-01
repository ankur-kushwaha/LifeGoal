import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../models/goal_model.dart';
import '../providers/goal_provider.dart';

class GoalFormScreen extends StatefulWidget {
  final GoalModel? goal;

  const GoalFormScreen({super.key, this.goal});

  @override
  State<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends State<GoalFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late String _name;
  late String _account;
  late double _targetCost;
  late DateTime _startDate;
  late DateTime _targetDate;
  late double _currentSavings;

  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _targetDateController = TextEditingController();
  final List<String> _suggestedAccounts = ['Ankur', 'Neha'];

  @override
  void initState() {
    super.initState();
    final g = widget.goal;
    _name = g?.name ?? '';
    _account = g?.account ?? 'Ankur';
    _targetCost = g?.targetCost ?? 0.0;
    _startDate = g?.startDate ?? DateTime(2026, 7, 1);
    _targetDate = g?.targetDate ?? DateTime(2028, 12, 31);
    _currentSavings = g?.currentSavings ?? 0.0;

    _startDateController.text = DateFormat('dd-MMM-yyyy').format(_startDate);
    _targetDateController.text = DateFormat('dd-MMM-yyyy').format(_targetDate);
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _targetDateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime initialDate = isStartDate ? _startDate : _targetDate;
    final DateTime firstDate = isStartDate ? DateTime(2015) : _startDate;
    final DateTime lastDate = DateTime(2065);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate) ? firstDate : initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
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
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          _startDateController.text = DateFormat('dd-MMM-yyyy').format(picked);
          // Auto-adjust target date if it's before new start date
          if (_targetDate.isBefore(_startDate)) {
            _targetDate = _startDate.add(const Duration(days: 30));
            _targetDateController.text = DateFormat('dd-MMM-yyyy').format(_targetDate);
          }
        } else {
          _targetDate = picked;
          _targetDateController.text = DateFormat('dd-MMM-yyyy').format(picked);
        }
      });
    }
  }

  Widget _buildInflationPreviewCard(double globalInflation) {
    final double years = GoalModel.monthsBetween(_startDate, _targetDate) / 12.0;
    final double inflatedAmount = _targetCost * pow(1 + (globalInflation / 100.0), years);
    
    final NumberFormat formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kMoneyGreen.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kMoneyGreen.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.trending_up, color: kMoneyGreen, size: 18),
              SizedBox(width: 8),
              Text(
                'Inflation Calculator Preview',
                style: TextStyle(
                  color: kMoneyGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Goal Amount', style: TextStyle(color: Colors.black38, fontSize: 9, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    formatter.format(_targetCost),
                    style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('Timeline', style: TextStyle(color: Colors.black38, fontSize: 9, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    '${years.toStringAsFixed(1)} years',
                    style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Inflated Target (${DateFormat('yyyy').format(_targetDate)})', style: const TextStyle(color: Colors.black38, fontSize: 9, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    formatter.format(inflatedAmount),
                    style: const TextStyle(color: kMoneyGreen, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '💡 At a ${globalInflation.toStringAsFixed(1)}% annual inflation rate, you will need ${formatter.format(inflatedAmount)} in future value to buy what costs ${formatter.format(_targetCost)} at the start date.',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.goal != null;
    final provider = Provider.of<GoalProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: kScaffoldBg,
      appBar: AppBar(
        backgroundColor: kCardBg,
        title: Text(isEditMode ? 'Edit Goal' : 'Create Life Goal', style: const TextStyle(color: Colors.black87)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Goal Details',
                style: TextStyle(color: kMoneyGreen, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),

              // Goal Name Field
              TextFormField(
                initialValue: _name,
                style: const TextStyle(color: Colors.black87),
                decoration: _inputDecoration('Goal Name', hint: 'e.g. DreamHome, Bali Vacation'),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter a goal name' : null,
                onSaved: (val) => _name = val!.trim(),
              ),
              const SizedBox(height: 16),

              // Account Name
              Row(
                children: [
                  Expanded(
                    child: Autocomplete<String>(
                      initialValue: TextEditingValue(text: _account),
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        return _suggestedAccounts.where((String option) {
                          return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                        });
                      },
                      onSelected: (String selection) {
                        setState(() {
                          _account = selection;
                        });
                      },
                      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          style: const TextStyle(color: Colors.black87),
                          decoration: _inputDecoration('Family Member / Account Name', hint: 'Ankur, Neha, etc.'),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Enter an account owner name' : null,
                          onSaved: (val) => _account = val!.trim(),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Goal Amount Field
              TextFormField(
                initialValue: _targetCost > 0 ? _targetCost.toStringAsFixed(0) : '',
                style: const TextStyle(color: Colors.black87),
                keyboardType: TextInputType.number,
                decoration: _inputDecoration('Goal Amount (at Start Date in ₹)', hint: 'e.g. 3000000').copyWith(
                  helperText: 'The amount you fill is based on the start date. The target amount will be calculated automatically.',
                  helperStyle: const TextStyle(color: Colors.black45, fontSize: 10),
                  helperMaxLines: 2,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter goal amount';
                  if (double.tryParse(val) == null || double.parse(val) <= 0) return 'Enter a valid positive number';
                  return null;
                },
                onChanged: (val) {
                  setState(() {
                    _targetCost = double.tryParse(val) ?? 0.0;
                  });
                },
                onSaved: (val) => _targetCost = double.parse(val!),
              ),
              const SizedBox(height: 16),

              // Timeline Section
              const Text(
                'Timeline',
                style: TextStyle(color: kMoneyGreen, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startDateController,
                      readOnly: true,
                      style: const TextStyle(color: Colors.black87),
                      decoration: _inputDecoration('Goal Start Date').copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(Icons.calendar_month, color: kMoneyGreen),
                          onPressed: () => _selectDate(context, true),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _targetDateController,
                      readOnly: true,
                      style: const TextStyle(color: Colors.black87),
                      decoration: _inputDecoration('Target Completion Date').copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(Icons.calendar_month, color: kMoneyGreen),
                          onPressed: () => _selectDate(context, false),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Real-Time Inflation Preview Card
              _buildInflationPreviewCard(provider.globalInflation),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kMoneyGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    isEditMode ? 'Save Changes' : 'Create Goal',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();

                      final newGoal = GoalModel(
                        id: widget.goal?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                        name: _name,
                        account: _account,
                        targetCost: _targetCost,
                        startDate: _startDate,
                        targetDate: _targetDate,
                        currentSavings: _currentSavings,
                        expectedReturn: null,
                        inflationRate: null,
                      );

                      if (isEditMode) {
                        provider.updateGoal(newGoal);
                      } else {
                        provider.addGoal(newGoal);
                      }

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isEditMode
                                ? 'Goal "${newGoal.name}" updated successfully!'
                                : 'Goal "${newGoal.name}" created successfully!',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.black54),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black26),
      fillColor: kCardBg,
      filled: true,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: kMoneyGreen),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}
