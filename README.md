# LifeGoal AI - Personal Financial Goal Planner

LifeGoal AI is a premium, inflation-aware financial goal planner built with Flutter. It replaces complex spreadsheet tracking with a sleek, automated mobile experience.

## Features
- 🎯 **Manage Multiple Financial Goals** - Home, Vacation, Education, Retirement, or any custom milestone.
- 📈 **Inflation-Aware Planning** - Instantly projects what your goal will cost in future terms.
- 💰 **Smart SIP Calculator** - Computes monthly investments needed using standard future value annuity formulas.
- 📊 **Real-Time Progress Tracking** - Watch overall and goal-specific completion percentages and status badges (On Track, Needs Attention, Behind Schedule).
- 👨‍👩‍👧 **Family Financial Planning** - Filter goals dynamically by account holder (e.g., Ankur, Neha) to view progress individually or combined.
- 📉 **Scenario Simulator (AI Engine)** - Simulate the impact of increasing SIP contributions or achieving different rates of return in real-time.
- 💾 **Local Persistence & Portability** - Data is saved securely on-device. Features full JSON backup export & restore functionality.

---

## Technical Stack
- **Framework:** Flutter (Material 3)
- **Language:** Dart
- **State Management:** Provider
- **Storage:** Shared Preferences (Offline/JSON serialization)

---

## Getting Started

### Prerequisites
- Flutter SDK (v3.0.0 or higher)
- Android SDK (to build for Android) or Google Chrome (to run on Web)

### 1. Install Dependencies
Run the following command in the workspace root to download the packages:
```bash
flutter pub get
```

### 2. Run Unit Tests
To verify all financial calculations (SIP requirements, inflation adjustments, compounding, and date-handling):
```bash
flutter test
```

### 3. Run the Application
Start the application on your connected Android device, emulator, or Chrome web browser:
```bash
# Run on default connected device (e.g. wirelessly connected Android device)
flutter run

# Run in Chrome (Web)
flutter run -d chrome
```

### 4. Build Android App (APK)
Compile a debug or release APK:
```bash
# Build Debug APK (Fastest compilation for testing)
flutter build apk --debug

# Build Release APK
flutter build apk --release
```
The compiled APK will be located at: `build/app/outputs/flutter-apk/app-debug.apk`.
