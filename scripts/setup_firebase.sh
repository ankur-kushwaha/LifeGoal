#!/usr/bin/env bash
# Registers the Android app, fetches google-services.json, generates
# firebase_options.dart, and deploys Auth + Firestore config.
set -euo pipefail

PROJECT_ID="${FIREBASE_PROJECT:-599945759594}"
PACKAGE_NAME="com.lifegoal.app.lifegoal_app"
APP_DISPLAY_NAME="LifeGoal AI"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT_DIR"

echo "==> Checking Firebase CLI login..."
if ! npx -y firebase-tools@latest login:list 2>/dev/null | grep -q "@"; then
  echo "Not logged in. Run: npx -y firebase-tools@latest login"
  exit 1
fi

echo "==> Using Firebase project: $PROJECT_ID"
npx -y firebase-tools@latest use "$PROJECT_ID"

echo "==> Listing existing Android apps..."
EXISTING_APP_ID="$(npx -y firebase-tools@latest apps:list ANDROID --project "$PROJECT_ID" 2>/dev/null \
  | awk -v pkg="$PACKAGE_NAME" '$0 ~ pkg { print $1; exit }' || true)"

if [[ -n "$EXISTING_APP_ID" && "$EXISTING_APP_ID" == 1:* ]]; then
  APP_ID="$EXISTING_APP_ID"
  echo "Found existing Android app: $APP_ID"
else
  echo "==> Registering Android app ($PACKAGE_NAME)..."
  CREATE_OUTPUT="$(npx -y firebase-tools@latest apps:create ANDROID "$APP_DISPLAY_NAME" \
    --package-name "$PACKAGE_NAME" \
    --project "$PROJECT_ID")"
  echo "$CREATE_OUTPUT"
  APP_ID="$(echo "$CREATE_OUTPUT" | grep -oE '1:[0-9]+:android:[a-f0-9]+' | head -1)"
  if [[ -z "$APP_ID" ]]; then
    echo "Could not parse App ID from create output. Check apps:list manually."
    exit 1
  fi
fi

echo "==> Downloading google-services.json..."
mkdir -p android/app
npx -y firebase-tools@latest apps:sdkconfig ANDROID "$APP_ID" --project "$PROJECT_ID" \
  > android/app/google-services.json

echo "==> Generating lib/firebase_options.dart..."
dart run tool/generate_firebase_options.dart

echo "==> Deploying Auth providers (email/password + Google)..."
npx -y firebase-tools@latest deploy --only auth --project "$PROJECT_ID"

echo "==> Deploying Firestore rules and indexes..."
npx -y firebase-tools@latest deploy --only firestore --project "$PROJECT_ID"

echo ""
echo "==> For Google Sign-In on Android, add your debug SHA-1 fingerprint:"
keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android 2>/dev/null \
  | grep -E 'SHA1|SHA-1' || echo "    (Run keytool manually if debug keystore is missing)"
echo ""
echo "Done. Run: flutter pub get && flutter run"
