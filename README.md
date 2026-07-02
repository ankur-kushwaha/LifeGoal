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
- Android SDK with platform tools (`adb`)
- A physical Android device (API 23 / Android 6.0 or higher) or an Android emulator

Verify your setup:
```bash
flutter doctor
```

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

---

## Install on Android Device

### Prepare your phone
1. On the device, open **Settings → About phone** and tap **Build number** seven times to enable Developer options.
2. Open **Settings → Developer options** and turn on **USB debugging**.
3. Connect the phone to your computer with a USB cable (or pair it for [wireless debugging](https://developer.android.com/studio/run/device#wireless)).
4. When prompted on the phone, tap **Allow** for the USB debugging authorization dialog.

Confirm Flutter sees the device:
```bash
flutter devices
```

You should see your phone listed (for example, `sdk gphone` or your device model name).

### Option A — Install and run directly (recommended for development)
From the project root, install and launch the app on the connected device:
```bash
flutter run
```

To target a specific device when more than one is connected:
```bash
flutter run -d <device-id>
```

Use the device ID shown by `flutter devices`.

### Option B — Build an APK and install manually
Useful when you want to share the app or install without keeping a USB session open.

**Debug APK** (fastest build, for testing):
```bash
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

**Release APK** (optimized, for everyday use):
```bash
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Without `adb`, copy the APK to the phone (email, cloud drive, etc.), open it in the Files app, and tap **Install**. You may need to allow installs from unknown sources in **Settings → Security**.

### Release signing (required for Play Store)
Signed release builds use `android/key.properties` and a keystore. Copy the example file and fill in your values before building:
```bash
cp android/key.properties.example android/key.properties
```

Generate a keystore if you do not have one yet:
```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Back up `upload-keystore.jks` and your passwords securely. You must use the same keystore for every Play Store update.

If `key.properties` is missing, release builds still compile but are signed with the debug key (not accepted by Google Play).

---

## Publish to Google Play Store

Google Play requires a signed **Android App Bundle (AAB)**, not an APK, for new listings and updates.

### 1. Create a Google Play Developer account
1. Go to [Google Play Console](https://play.google.com/console).
2. Sign in with a Google account and pay the one-time developer registration fee.
3. Complete the developer profile (name, contact email, etc.).

### 2. Configure release signing
Follow the **Release signing** steps above. Your `android/key.properties` should point to `upload-keystore.jks` in the project root.

For Play App Signing, Google will manage the app signing key. Upload your **upload key** (the keystore you generated) when prompted during your first release.

### 3. Bump the app version
Edit `pubspec.yaml` before each store release. The format is `versionName+versionCode`:

```yaml
version: 1.0.1+2   # 1.0.1 = user-facing version, 2 = internal build number (must increase every upload)
```

- **versionName** — shown to users on the Play Store (e.g. `1.0.1`)
- **versionCode** — must be a higher integer than any previous upload (e.g. `2`, `3`, …)

You can also override at build time:
```bash
flutter build appbundle --release --build-name=1.0.1 --build-number=2
```

### 4. Build the release App Bundle
From the project root:
```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

The signed bundle is output to:
```
build/app/outputs/bundle/release/app-release.aab
```

Verify the build locally (optional):
```bash
bundletool build-apks --bundle=build/app/outputs/bundle/release/app-release.aab --output=/tmp/lifegoal.apks --mode=universal
```

### 5. Create the app in Play Console
1. In Play Console, click **Create app**.
2. Fill in the app name (**LifeGoal AI**), default language, and app/game type.
3. Accept the declarations (policies, US export laws, etc.).

Use the package name **`com.lifegoal.app.lifegoal_app`** — it must match `applicationId` in `android/app/build.gradle.kts` and cannot be changed later.

### 6. Complete the store listing
Under **Grow → Store presence → Main store listing**, provide:

| Item | Notes |
|------|-------|
| Short description | Up to 80 characters |
| Full description | Up to 4,000 characters |
| App icon | 512 × 512 PNG |
| Feature graphic | 1,024 × 500 PNG |
| Phone screenshots | At least 2 (recommended 4–8) |

Also complete required policy sections under **Policy and programs**:
- **App content** — privacy policy URL, ads declaration, content rating questionnaire, target audience, data safety form
- **Privacy policy** — required because the app uses Firebase Authentication

### 7. Upload and roll out
1. Open **Release → Testing → Internal testing** (or **Production** when ready).
2. Click **Create new release**.
3. Upload `app-release.aab`.
4. Add release notes for testers/users.
5. Review and **Start rollout**.

Recommended rollout path:
1. **Internal testing** — quick validation with a small team
2. **Closed / Open testing** — broader beta feedback
3. **Production** — public release (staged rollout recommended)

### 8. Pre-launch checklist
- [ ] `flutter test` passes
- [ ] Release bundle built with production signing (`key.properties` configured)
- [ ] Version code incremented in `pubspec.yaml`
- [ ] `google-services.json` matches your production Firebase project
- [ ] Store listing assets and descriptions are complete
- [ ] Privacy policy URL is live and linked in Play Console
- [ ] Data safety and content rating forms submitted
- [ ] App tested on a physical device from an internal testing track

### Updating an existing Play Store release
For each new version:
1. Increment `version` in `pubspec.yaml` (bump the build number at minimum).
2. Run `flutter build appbundle --release`.
3. Upload the new `.aab` to the desired track in Play Console.
4. Submit for review and roll out.

---

## Run on Web (optional)
```bash
flutter run -d chrome
```

---

## Deploy Web App (Firebase Hosting)

The Flutter app is the web UI and runs on the **same Firebase project** (`mymaps-b534f`) as Auth and Firestore.

### First-time setup

1. Register Android + Web apps and generate config:
   ```bash
   bash scripts/setup_firebase.sh
   ```
2. Deploy Auth so hosting domains work for sign-in:
   ```bash
   npx -y firebase-tools@latest deploy --only auth --project mymaps-b534f
   ```

### Build and deploy

```bash
bash scripts/deploy_web.sh
```

Live URLs after deploy:
- https://mymaps-b534f.web.app
- https://mymaps-b534f.firebaseapp.com

### Preview locally

```bash
flutter build web --release
npx -y firebase-tools@latest emulators:start --only hosting
```

### PWA (installable web app)

The web build is a Progressive Web App:
- **Install** from Chrome/Edge (address bar or in-app banner on the dashboard)
- **Offline shell** — app loads from cache; data syncs when back online (Firestore offline persistence)
- **Home screen icon** on Android and iOS Safari (Add to Home Screen)

After changing `web/sw.js`, bump `CACHE_NAME` inside that file before redeploying so clients pick up updates.

### Privacy policy URL (Play Store)

Use this URL in Google Play Console and other store listings:

```
https://mymaps-b534f.web.app/privacy.html
```

The policy is also available in-app from the account menu and sign-in screen.
