enum HousingStatus {
  rent,
  own,
  planningToBuy;

  static HousingStatus fromString(String? value) {
    switch (value) {
      case 'own':
        return HousingStatus.own;
      case 'planning_to_buy':
        return HousingStatus.planningToBuy;
      default:
        return HousingStatus.rent;
    }
  }

  String toJson() {
    switch (this) {
      case HousingStatus.own:
        return 'own';
      case HousingStatus.planningToBuy:
        return 'planning_to_buy';
      case HousingStatus.rent:
        return 'rent';
    }
  }

  String get label {
    switch (this) {
      case HousingStatus.own:
        return 'Own home';
      case HousingStatus.planningToBuy:
        return 'Planning to buy';
      case HousingStatus.rent:
        return 'Renting';
    }
  }
}

enum EmploymentType {
  salaried,
  business,
  freelancer,
  homemaker,
  other;

  static EmploymentType fromString(String? value) {
    switch (value) {
      case 'business':
        return EmploymentType.business;
      case 'freelancer':
        return EmploymentType.freelancer;
      case 'homemaker':
        return EmploymentType.homemaker;
      case 'other':
        return EmploymentType.other;
      default:
        return EmploymentType.salaried;
    }
  }

  String toJson() => name;

  String get label {
    switch (this) {
      case EmploymentType.salaried:
        return 'Salaried';
      case EmploymentType.business:
        return 'Business';
      case EmploymentType.freelancer:
        return 'Freelancer';
      case EmploymentType.homemaker:
        return 'Homemaker';
      case EmploymentType.other:
        return 'Other';
    }
  }
}

enum RiskAppetite {
  conservative,
  moderate,
  aggressive;

  static RiskAppetite fromString(String? value) {
    switch (value) {
      case 'conservative':
        return RiskAppetite.conservative;
      case 'aggressive':
        return RiskAppetite.aggressive;
      default:
        return RiskAppetite.moderate;
    }
  }

  String toJson() => name;

  String get label {
    switch (this) {
      case RiskAppetite.conservative:
        return 'Conservative';
      case RiskAppetite.moderate:
        return 'Moderate';
      case RiskAppetite.aggressive:
        return 'Aggressive';
    }
  }
}

enum LoanType {
  home,
  personal,
  car,
  education,
  other;

  static LoanType fromString(String? value) {
    switch (value) {
      case 'home':
        return LoanType.home;
      case 'car':
        return LoanType.car;
      case 'education':
        return LoanType.education;
      case 'other':
        return LoanType.other;
      default:
        return LoanType.personal;
    }
  }

  String toJson() => name;

  String get label {
    switch (this) {
      case LoanType.home:
        return 'Home loan';
      case LoanType.personal:
        return 'Personal loan';
      case LoanType.car:
        return 'Car loan';
      case LoanType.education:
        return 'Education loan';
      case LoanType.other:
        return 'Other';
    }
  }
}

enum DependentRelationship {
  child,
  parent,
  spouse,
  other;

  static DependentRelationship fromString(String? value) {
    switch (value) {
      case 'parent':
        return DependentRelationship.parent;
      case 'spouse':
        return DependentRelationship.spouse;
      case 'other':
        return DependentRelationship.other;
      default:
        return DependentRelationship.child;
    }
  }

  String toJson() => name;

  String get label {
    switch (this) {
      case DependentRelationship.child:
        return 'Child';
      case DependentRelationship.parent:
        return 'Parent';
      case DependentRelationship.spouse:
        return 'Spouse';
      case DependentRelationship.other:
        return 'Other';
    }
  }
}

class Dependent {
  final String id;
  final String name;
  final DependentRelationship relationship;
  final DateTime? dateOfBirth;

  const Dependent({
    required this.id,
    required this.name,
    required this.relationship,
    this.dateOfBirth,
  });

  int? get ageYears {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    var age = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      age--;
    }
    return age;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'relationship': relationship.toJson(),
        if (dateOfBirth != null) 'dateOfBirth': dateOfBirth!.toIso8601String(),
      };

  factory Dependent.fromJson(Map<String, dynamic> json) {
    return Dependent(
      id: json['id'] as String,
      name: json['name'] as String,
      relationship: DependentRelationship.fromString(json['relationship'] as String?),
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.parse(json['dateOfBirth'] as String)
          : null,
    );
  }

  Dependent copyWith({
    String? name,
    DependentRelationship? relationship,
    DateTime? dateOfBirth,
  }) {
    return Dependent(
      id: id,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    );
  }
}

class FamilyLoan {
  final String id;
  final LoanType type;
  final String? lenderName;
  final double emi;
  final double? outstandingAmount;
  final int remainingMonths;

  const FamilyLoan({
    required this.id,
    required this.type,
    this.lenderName,
    required this.emi,
    this.outstandingAmount,
    required this.remainingMonths,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.toJson(),
        if (lenderName != null && lenderName!.isNotEmpty) 'lenderName': lenderName,
        'emi': emi,
        if (outstandingAmount != null) 'outstandingAmount': outstandingAmount,
        'remainingMonths': remainingMonths,
      };

  factory FamilyLoan.fromJson(Map<String, dynamic> json) {
    return FamilyLoan(
      id: json['id'] as String,
      type: LoanType.fromString(json['type'] as String?),
      lenderName: json['lenderName'] as String?,
      emi: (json['emi'] as num).toDouble(),
      outstandingAmount: (json['outstandingAmount'] as num?)?.toDouble(),
      remainingMonths: json['remainingMonths'] as int,
    );
  }

  FamilyLoan copyWith({
    LoanType? type,
    String? lenderName,
    double? emi,
    double? outstandingAmount,
    int? remainingMonths,
  }) {
    return FamilyLoan(
      id: id,
      type: type ?? this.type,
      lenderName: lenderName ?? this.lenderName,
      emi: emi ?? this.emi,
      outstandingAmount: outstandingAmount ?? this.outstandingAmount,
      remainingMonths: remainingMonths ?? this.remainingMonths,
    );
  }
}

class FamilyProfile {
  final double? monthlyHouseholdIncome;
  final double? monthlyHouseholdExpenses;
  final int emergencyFundMonths;
  final HousingStatus housingStatus;
  final bool hasHealthInsurance;
  final bool hasLifeInsurance;
  final List<Dependent> dependents;
  final List<FamilyLoan> loans;
  final DateTime? updatedAt;

  const FamilyProfile({
    this.monthlyHouseholdIncome,
    this.monthlyHouseholdExpenses,
    this.emergencyFundMonths = 6,
    this.housingStatus = HousingStatus.rent,
    this.hasHealthInsurance = false,
    this.hasLifeInsurance = false,
    this.dependents = const [],
    this.loans = const [],
    this.updatedAt,
  });

  double get totalMonthlyEmi => loans.fold(0.0, (sum, loan) => sum + loan.emi);

  double? get monthlySurplus {
    if (monthlyHouseholdIncome == null || monthlyHouseholdExpenses == null) return null;
    return monthlyHouseholdIncome! - monthlyHouseholdExpenses! - totalMonthlyEmi;
  }

  double? get emergencyFundTarget {
    if (monthlyHouseholdExpenses == null) return null;
    return monthlyHouseholdExpenses! * emergencyFundMonths;
  }

  bool get isEmpty =>
      monthlyHouseholdIncome == null &&
      monthlyHouseholdExpenses == null &&
      dependents.isEmpty &&
      loans.isEmpty;

  Map<String, dynamic> toJson() => {
        if (monthlyHouseholdIncome != null) 'monthlyHouseholdIncome': monthlyHouseholdIncome,
        if (monthlyHouseholdExpenses != null) 'monthlyHouseholdExpenses': monthlyHouseholdExpenses,
        'emergencyFundMonths': emergencyFundMonths,
        'housingStatus': housingStatus.toJson(),
        'hasHealthInsurance': hasHealthInsurance,
        'hasLifeInsurance': hasLifeInsurance,
        'dependents': dependents.map((d) => d.toJson()).toList(),
        'loans': loans.map((l) => l.toJson()).toList(),
        'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
      };

  factory FamilyProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const FamilyProfile();
    return FamilyProfile(
      monthlyHouseholdIncome: (json['monthlyHouseholdIncome'] as num?)?.toDouble(),
      monthlyHouseholdExpenses: (json['monthlyHouseholdExpenses'] as num?)?.toDouble(),
      emergencyFundMonths: json['emergencyFundMonths'] as int? ?? 6,
      housingStatus: HousingStatus.fromString(json['housingStatus'] as String?),
      hasHealthInsurance: json['hasHealthInsurance'] as bool? ?? false,
      hasLifeInsurance: json['hasLifeInsurance'] as bool? ?? false,
      dependents: (json['dependents'] as List<dynamic>? ?? [])
          .map((e) => Dependent.fromJson(e as Map<String, dynamic>))
          .toList(),
      loans: (json['loans'] as List<dynamic>? ?? [])
          .map((e) => FamilyLoan.fromJson(e as Map<String, dynamic>))
          .toList(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  FamilyProfile copyWith({
    double? monthlyHouseholdIncome,
    double? monthlyHouseholdExpenses,
    int? emergencyFundMonths,
    HousingStatus? housingStatus,
    bool? hasHealthInsurance,
    bool? hasLifeInsurance,
    List<Dependent>? dependents,
    List<FamilyLoan>? loans,
  }) {
    return FamilyProfile(
      monthlyHouseholdIncome: monthlyHouseholdIncome ?? this.monthlyHouseholdIncome,
      monthlyHouseholdExpenses: monthlyHouseholdExpenses ?? this.monthlyHouseholdExpenses,
      emergencyFundMonths: emergencyFundMonths ?? this.emergencyFundMonths,
      housingStatus: housingStatus ?? this.housingStatus,
      hasHealthInsurance: hasHealthInsurance ?? this.hasHealthInsurance,
      hasLifeInsurance: hasLifeInsurance ?? this.hasLifeInsurance,
      dependents: dependents ?? this.dependents,
      loans: loans ?? this.loans,
      updatedAt: DateTime.now(),
    );
  }
}

class MemberProfile {
  final DateTime? dateOfBirth;
  final double? monthlyIncome;
  final double? monthlyExpenses;
  final EmploymentType employmentType;
  final RiskAppetite riskAppetite;
  final int retirementAge;
  final DateTime? updatedAt;

  const MemberProfile({
    this.dateOfBirth,
    this.monthlyIncome,
    this.monthlyExpenses,
    this.employmentType = EmploymentType.salaried,
    this.riskAppetite = RiskAppetite.moderate,
    this.retirementAge = 60,
    this.updatedAt,
  });

  int? get ageYears {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    var age = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      age--;
    }
    return age;
  }

  bool get isEmpty =>
      dateOfBirth == null && monthlyIncome == null && monthlyExpenses == null;

  Map<String, dynamic> toJson() => {
        if (dateOfBirth != null) 'dateOfBirth': dateOfBirth!.toIso8601String(),
        if (monthlyIncome != null) 'monthlyIncome': monthlyIncome,
        if (monthlyExpenses != null) 'monthlyExpenses': monthlyExpenses,
        'employmentType': employmentType.toJson(),
        'riskAppetite': riskAppetite.toJson(),
        'retirementAge': retirementAge,
        'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
      };

  factory MemberProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MemberProfile();
    return MemberProfile(
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.parse(json['dateOfBirth'] as String)
          : null,
      monthlyIncome: (json['monthlyIncome'] as num?)?.toDouble(),
      monthlyExpenses: (json['monthlyExpenses'] as num?)?.toDouble(),
      employmentType: EmploymentType.fromString(json['employmentType'] as String?),
      riskAppetite: RiskAppetite.fromString(json['riskAppetite'] as String?),
      retirementAge: json['retirementAge'] as int? ?? 60,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  MemberProfile copyWith({
    DateTime? dateOfBirth,
    double? monthlyIncome,
    double? monthlyExpenses,
    EmploymentType? employmentType,
    RiskAppetite? riskAppetite,
    int? retirementAge,
  }) {
    return MemberProfile(
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      monthlyExpenses: monthlyExpenses ?? this.monthlyExpenses,
      employmentType: employmentType ?? this.employmentType,
      riskAppetite: riskAppetite ?? this.riskAppetite,
      retirementAge: retirementAge ?? this.retirementAge,
      updatedAt: DateTime.now(),
    );
  }
}
