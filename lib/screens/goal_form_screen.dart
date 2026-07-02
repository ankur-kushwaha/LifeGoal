import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../models/goal_model.dart';
import '../providers/goal_provider.dart';

class _GoalPreset {
  final String id;
  final String label;
  final IconData icon;
  final double exampleAmount;
  final String nameSuggestion;

  const _GoalPreset({
    required this.id,
    required this.label,
    required this.icon,
    required this.exampleAmount,
    required this.nameSuggestion,
  });
}

const _goalPresets = [
  _GoalPreset(id: 'home', label: 'Home', icon: Icons.home_outlined, exampleAmount: 5000000, nameSuggestion: 'Dream Home'),
  _GoalPreset(id: 'vacation', label: 'Vacation', icon: Icons.flight_outlined, exampleAmount: 200000, nameSuggestion: 'Bali Vacation'),
  _GoalPreset(id: 'education', label: 'Education', icon: Icons.school_outlined, exampleAmount: 2000000, nameSuggestion: 'Child Education'),
  _GoalPreset(id: 'retirement', label: 'Retirement', icon: Icons.beach_access_outlined, exampleAmount: 10000000, nameSuggestion: 'Retirement Fund'),
];

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
  late double _manualTargetAmount;
  late DateTime _startDate;
  late DateTime _targetDate;
  late double _currentSavings;
  late double _goalInflationRate;
  late bool _useManualTarget;
  String? _selectedPresetId;

  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _targetDateController = TextEditingController();
  final TextEditingController _todayValueController = TextEditingController();
  final TextEditingController _manualTargetController = TextEditingController();
  @override
  void initState() {
    super.initState();
    final g = widget.goal;
    final provider = Provider.of<GoalProvider>(context, listen: false);
    final defaultAccount = provider.currentMember?.label ??
        (provider.accounts.isNotEmpty ? provider.accounts.first : 'Me');
    _name = g?.name ?? '';
    _account = g?.account ?? defaultAccount;
    _targetCost = g?.targetCost ?? 0.0;
    _startDate = g?.startDate ?? provider.today;
    _targetDate = g?.targetDate ?? provider.today.add(const Duration(days: 365 * 3));
    _currentSavings = g?.currentSavings ?? 0.0;
    _goalInflationRate = g?.inflationRate ?? provider.globalInflation;
    _useManualTarget = false;

    final years = GoalModel.monthsBetween(_startDate, _targetDate) / 12.0;
    final rate = _goalInflationRate / 100.0;
    _manualTargetAmount = _targetCost > 0 && years > 0
        ? _targetCost * pow(1 + rate, years)
        : 0.0;

    _startDateController.text = DateFormat('dd-MMM-yyyy').format(_startDate);
    _targetDateController.text = DateFormat('dd-MMM-yyyy').format(_targetDate);
    if (_targetCost > 0) {
      _todayValueController.text = _targetCost.toStringAsFixed(0);
    }
    if (_manualTargetAmount > 0) {
      _manualTargetController.text = _manualTargetAmount.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _targetDateController.dispose();
    _todayValueController.dispose();
    _manualTargetController.dispose();
    super.dispose();
  }

  double get _years => GoalModel.monthsBetween(_startDate, _targetDate) / 12.0;

  double _inflatedTargetAmount() {
    if (_years <= 0) return _targetCost;
    return _targetCost * pow(1 + (_goalInflationRate / 100.0), _years);
  }

  double _backCalculateTodayValue(double futureAmount) {
    if (_years <= 0 || futureAmount <= 0) return futureAmount;
    return futureAmount / pow(1 + (_goalInflationRate / 100.0), _years);
  }

  void _syncAmountsFromTodayValue() {
    _manualTargetAmount = _inflatedTargetAmount();
    if (_manualTargetAmount > 0) {
      _manualTargetController.text = _manualTargetAmount.toStringAsFixed(0);
    }
  }

  void _syncAmountsFromManualTarget() {
    _targetCost = _backCalculateTodayValue(_manualTargetAmount);
    if (_targetCost > 0) {
      _todayValueController.text = _targetCost.toStringAsFixed(0);
    }
  }

  void _applyPreset(_GoalPreset preset) {
    setState(() {
      _selectedPresetId = preset.id;
      if (_name.trim().isEmpty) {
        _name = preset.nameSuggestion;
      }
      _targetCost = preset.exampleAmount;
      _todayValueController.text = preset.exampleAmount.toStringAsFixed(0);
      _syncAmountsFromTodayValue();
    });
  }

  void _setTargetDateYears(int years) {
    setState(() {
      _targetDate = DateTime(_startDate.year + years, _startDate.month, _startDate.day);
      _targetDateController.text = DateFormat('dd-MMM-yyyy').format(_targetDate);
      if (_useManualTarget) {
        _syncAmountsFromManualTarget();
      } else {
        _syncAmountsFromTodayValue();
      }
    });
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
          if (_targetDate.isBefore(_startDate)) {
            _targetDate = _startDate.add(const Duration(days: 30));
            _targetDateController.text = DateFormat('dd-MMM-yyyy').format(_targetDate);
          }
        } else {
          _targetDate = picked;
          _targetDateController.text = DateFormat('dd-MMM-yyyy').format(picked);
        }
        if (_useManualTarget) {
          _syncAmountsFromManualTarget();
        } else {
          _syncAmountsFromTodayValue();
        }
      });
    }
  }

  NumberFormat get _currencyFormatter => NumberFormat.currency(
        locale: 'en_IN',
        symbol: '₹',
        decimalDigits: 0,
      );

  Widget _buildPresetChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _goalPresets.map((preset) {
        final isSelected = _selectedPresetId == preset.id;
        return FilterChip(
          label: Text(preset.label),
          avatar: Icon(preset.icon, size: 16, color: isSelected ? kMoneyGreen : Colors.black45),
          selected: isSelected,
          selectedColor: kMoneyGreen.withValues(alpha: 0.12),
          checkmarkColor: kMoneyGreen,
          labelStyle: TextStyle(
            color: isSelected ? kMoneyGreen : Colors.black54,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 12,
          ),
          side: BorderSide(color: isSelected ? kMoneyGreen.withValues(alpha: 0.4) : Colors.black12),
          onSelected: (_) => _applyPreset(preset),
        );
      }).toList(),
    );
  }

  Widget _buildQuickDateChips() {
    const options = [
      (label: '1 year', years: 1),
      (label: '3 years', years: 3),
      (label: '5 years', years: 5),
      (label: '10 years', years: 10),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        return ActionChip(
          label: Text(option.label, style: const TextStyle(fontSize: 12)),
          backgroundColor: kCardBg,
          side: const BorderSide(color: Colors.black12),
          onPressed: () => _setTargetDateYears(option.years),
        );
      }).toList(),
    );
  }

  Widget _buildManualTargetToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text(
          'I already know my target amount',
          style: TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        subtitle: const Text(
          'Enter the future amount you need — we\'ll estimate today\'s value.',
          style: TextStyle(color: Colors.black45, fontSize: 11),
        ),
        value: _useManualTarget,
        activeThumbColor: kMoneyGreen,
        onChanged: (val) {
          setState(() {
            _useManualTarget = val;
            if (val) {
              _syncAmountsFromManualTarget();
            } else {
              _syncAmountsFromTodayValue();
            }
          });
        },
      ),
    );
  }

  Widget _buildInflationSlider(double globalInflation) {
    final isCustom = (_goalInflationRate - globalInflation).abs() > 0.05;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Inflation rate for this goal',
              style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            Text(
              '${_goalInflationRate.toStringAsFixed(1)}%',
              style: const TextStyle(color: kMoneyGreen, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Slider(
          value: _goalInflationRate,
          min: 0,
          max: 20,
          divisions: 40,
          activeColor: kMoneyGreen,
          inactiveColor: Colors.black12,
          onChanged: (val) {
            setState(() {
              _goalInflationRate = val;
              if (_useManualTarget) {
                _syncAmountsFromManualTarget();
              } else {
                _syncAmountsFromTodayValue();
              }
            });
          },
        ),
        Text(
          isCustom
              ? 'Using a custom rate for this goal (global default: ${globalInflation.toStringAsFixed(1)}%).'
              : 'Using the global default rate. Slide to override for this goal.',
          style: const TextStyle(color: Colors.black45, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildTargetSummaryCard(double globalInflation) {
    final inflatedAmount = _useManualTarget ? _manualTargetAmount : _inflatedTargetAmount();
    final todayValue = _useManualTarget ? _backCalculateTodayValue(_manualTargetAmount) : _targetCost;
    final hasValidInput = inflatedAmount > 0 && _years > 0;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kMoneyGreen.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kMoneyGreen.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.flag_outlined, color: kMoneyGreen, size: 18),
              SizedBox(width: 8),
              Text(
                'Your Target Amount',
                style: TextStyle(
                  color: kMoneyGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasValidInput)
            Text(
              _useManualTarget
                  ? 'Enter your target amount and date to see the estimated today\'s value.'
                  : 'Enter today\'s value and target date to see your inflation-adjusted target.',
              style: const TextStyle(color: Colors.black45, fontSize: 12),
            )
          else ...[
            Text(
              _currencyFormatter.format(inflatedAmount),
              style: const TextStyle(
                color: kMoneyGreen,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'needed by ${DateFormat('dd MMM yyyy').format(_targetDate)}',
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _buildInflationFlowRow(
              todayValue: todayValue,
              years: _years,
              inflatedAmount: inflatedAmount,
              inflationRate: _goalInflationRate,
            ),
            const SizedBox(height: 16),
            _buildInflationSlider(globalInflation),
          ],
        ],
      ),
    );
  }

  Widget _buildInflationFlowRow({
    required double todayValue,
    required double years,
    required double inflatedAmount,
    required double inflationRate,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TODAY\'S VALUE',
                  style: TextStyle(color: Colors.black38, fontSize: 9, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  _currencyFormatter.format(todayValue),
                  style: TextStyle(
                    color: _useManualTarget ? Colors.black54 : Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              children: [
                Icon(Icons.arrow_forward, color: kMoneyGreen.withValues(alpha: 0.7), size: 16),
                Text(
                  '${years.toStringAsFixed(1)}y @ ${inflationRate.toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.black38, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'TARGET AMOUNT',
                  style: TextStyle(color: Colors.black38, fontSize: 9, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  _currencyFormatter.format(inflatedAmount),
                  style: TextStyle(
                    color: kMoneyGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double? _inflationRateToSave(double globalInflation) {
    if ((_goalInflationRate - globalInflation).abs() < 0.05) {
      return null;
    }
    return _goalInflationRate;
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

              const Text(
                'Quick start',
                style: TextStyle(color: Colors.black45, fontSize: 11, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              _buildPresetChips(),
              const SizedBox(height: 16),

              TextFormField(
                initialValue: _name,
                key: ValueKey('name_$_selectedPresetId'),
                style: const TextStyle(color: Colors.black87),
                decoration: _inputDecoration('Goal Name', hint: 'e.g. DreamHome, Bali Vacation'),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter a goal name' : null,
                onSaved: (val) => _name = val!.trim(),
              ),
              const SizedBox(height: 16),

              Autocomplete<String>(
                initialValue: TextEditingValue(text: _account),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  final provider = Provider.of<GoalProvider>(context, listen: false);
                  final suggestions = provider.accounts;
                  if (textEditingValue.text.isEmpty) return suggestions;
                  return suggestions.where((String option) {
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
              const SizedBox(height: 24),

              const Text(
                'Cost & Timeline',
                style: TextStyle(color: kMoneyGreen, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                _useManualTarget
                    ? 'Enter the amount you\'ll need on your target date.'
                    : 'Tell us what the goal costs today — we\'ll estimate the future amount using inflation.',
                style: const TextStyle(color: Colors.black45, fontSize: 12),
              ),
              const SizedBox(height: 12),

              _buildManualTargetToggle(),
              const SizedBox(height: 16),

              if (_useManualTarget)
                TextFormField(
                  controller: _manualTargetController,
                  style: const TextStyle(color: Colors.black87),
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration(
                    'Target amount on completion date (₹)',
                    hint: 'e.g. 45,00,000',
                  ).copyWith(
                    prefixIcon: const Icon(Icons.flag_outlined, color: Colors.black38),
                    helperText: 'The total you expect to need by your target date.',
                    helperStyle: const TextStyle(color: Colors.black45, fontSize: 10),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Enter target amount';
                    if (double.tryParse(val) == null || double.parse(val) <= 0) return 'Enter a valid positive number';
                    return null;
                  },
                  onChanged: (val) {
                    setState(() {
                      _manualTargetAmount = double.tryParse(val) ?? 0.0;
                      _syncAmountsFromManualTarget();
                    });
                  },
                  onSaved: (val) => _manualTargetAmount = double.parse(val!),
                )
              else
                TextFormField(
                  controller: _todayValueController,
                  style: const TextStyle(color: Colors.black87),
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration(
                    'What does this cost today? (₹)',
                    hint: 'e.g. 30,00,000 for a home down payment',
                  ).copyWith(
                    prefixIcon: const Icon(Icons.payments_outlined, color: Colors.black38),
                    helperText: 'Enter the price in today\'s terms — like a house listing price or trip budget right now.',
                    helperStyle: const TextStyle(color: Colors.black45, fontSize: 10),
                    helperMaxLines: 2,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Enter today\'s value';
                    if (double.tryParse(val) == null || double.parse(val) <= 0) return 'Enter a valid positive number';
                    return null;
                  },
                  onChanged: (val) {
                    setState(() {
                      _targetCost = double.tryParse(val) ?? 0.0;
                      _syncAmountsFromTodayValue();
                    });
                  },
                  onSaved: (val) => _targetCost = double.parse(val!),
                ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _targetDateController,
                readOnly: true,
                style: const TextStyle(color: Colors.black87),
                decoration: _inputDecoration(
                  'When do you want to achieve this?',
                  hint: 'Target completion date',
                ).copyWith(
                  prefixIcon: const Icon(Icons.event_outlined, color: Colors.black38),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_month, color: kMoneyGreen),
                    onPressed: () => _selectDate(context, false),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Quick timeline',
                style: TextStyle(color: Colors.black45, fontSize: 11, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              _buildQuickDateChips(),
              const SizedBox(height: 12),

              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: const Text(
                  'Advanced options',
                  style: TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                children: [
                  TextFormField(
                    controller: _startDateController,
                    readOnly: true,
                    style: const TextStyle(color: Colors.black87),
                    decoration: _inputDecoration('Planning start date').copyWith(
                      helperText: 'When you begin saving toward this goal. Defaults to today.',
                      helperStyle: const TextStyle(color: Colors.black45, fontSize: 10),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_month, color: kMoneyGreen),
                        onPressed: () => _selectDate(context, true),
                      ),
                    ),
                  ),
                ],
              ),

              _buildTargetSummaryCard(provider.globalInflation),
              const SizedBox(height: 24),

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
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;
                    _formKey.currentState!.save();

                    final savedTargetCost = _useManualTarget
                        ? _backCalculateTodayValue(_manualTargetAmount)
                        : _targetCost;

                    final newGoal = GoalModel(
                      id: widget.goal?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                      name: _name,
                      account: _account,
                      targetCost: savedTargetCost,
                      startDate: _startDate,
                      targetDate: _targetDate,
                      currentSavings: _currentSavings,
                      expectedReturn: widget.goal?.expectedReturn,
                      inflationRate: _inflationRateToSave(provider.globalInflation),
                    );

                    try {
                      if (isEditMode) {
                        await provider.updateGoal(newGoal);
                      } else {
                        await provider.addGoal(newGoal);
                      }
                      if (!context.mounted) return;
                      Navigator.pop(context, newGoal.account);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isEditMode
                                ? 'Goal "${newGoal.name}" updated successfully!'
                                : 'Goal "${newGoal.name}" created successfully!',
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(e.toString().replaceAll('Exception:', '').trim()),
                          backgroundColor: Colors.redAccent,
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
