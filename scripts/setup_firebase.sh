#!/usr/bin/env bash
# Registers Android + Web apps, generates firebase_options.dart, deploys Auth/Firestore/Hosting config.
set -euo pipefail

PROJECT_ID="${FIREBASE_PROJECT:-mymaps-b534f}"
PACKAGE_NAME="com.lifegoal.app.lifegoal_app"
APP_DISPLAY_NAME="LifeGoal AI"
WEB_APP_DISPLAY_NAME="LifeGoal AI Web"
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
APPS_JSON="$(npx -y firebase-tools@latest apps:list ANDROID --project "$PROJECT_ID" --json 2>/dev/null || echo '{"result":[]}')"
EXISTING_APP_ID="$(echo "$APPS_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
pkg = '$PACKAGE_NAME'
for app in data.get('result', []):
    if app.get('packageName') == pkg:
        print(app['appId'])
        break
")"

if [[ -n "$EXISTING_APP_ID" && "$EXISTING_APP_ID" == 1:* ]]; then
  APP_ID="$EXISTING_APP_ID"
  echo "Found existing Android app: $APP_ID"
else
  echo "==> Registering Android app ($PACKAGE_NAME)..."
  if ! CREATE_OUTPUT="$(npx -y firebase-tools@latest apps:create ANDROID "$APP_DISPLAY_NAME" \
    --package-name "$PACKAGE_NAME" \
    --project "$PROJECT_ID" 2>&1)"; then
    echo "$CREATE_OUTPUT"
    # App may already exist but was not matched above — re-list and try again.
    APPS_JSON="$(npx -y firebase-tools@latest apps:list ANDROID --project "$PROJECT_ID" --json 2>/dev/null || echo '{"result":[]}')"
    EXISTING_APP_ID="$(echo "$APPS_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
pkg = '$PACKAGE_NAME'
for app in data.get('result', []):
    if app.get('packageName') == pkg:
        print(app['appId'])
        break
")"
    if [[ -n "$EXISTING_APP_ID" && "$EXISTING_APP_ID" == 1:* ]]; then
      APP_ID="$EXISTING_APP_ID"
      echo "Found existing Android app after create conflict: $APP_ID"
    else
      echo "Could not create or find Android app. Check Firebase Console."
      exit 1
    fi
  else
    echo "$CREATE_OUTPUT"
    APP_ID="$(echo "$CREATE_OUTPUT" | grep -oE '1:[0-9]+:android:[a-f0-9]+' | head -1)"
    if [[ -z "$APP_ID" ]]; then
      echo "Could not parse App ID from create output. Check apps:list manually."
      exit 1
    fi
  fi
fi

echo "==> Downloading google-services.json..."
mkdir -p android/app
npx -y firebase-tools@latest apps:sdkconfig ANDROID "$APP_ID" --project "$PROJECT_ID" \
  > android/app/google-services.json

echo "==> Listing existing Web apps..."
WEB_APPS_JSON="$(npx -y firebase-tools@latest apps:list WEB --project "$PROJECT_ID" --json 2>/dev/null || echo '{"result":[]}')"
WEB_APP_ID="$(echo "$WEB_APPS_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
apps = data.get('result', [])
print(apps[0]['appId'] if apps else '')
")"

if [[ -z "$WEB_APP_ID" ]]; then
  echo "==> Registering Web app..."
  WEB_CREATE_OUTPUT="$(npx -y firebase-tools@latest apps:create WEB "$WEB_APP_DISPLAY_NAME" \
    --project "$PROJECT_ID")"
  echo "$WEB_CREATE_OUTPUT"
  WEB_APP_ID="$(echo "$WEB_CREATE_OUTPUT" | grep -oE '1:[0-9]+:web:[a-f0-9]+' | head -1)"
fi

if [[ -z "$WEB_APP_ID" ]]; then
  echo "Could not find or create a Web app. Check Firebase Console."
  exit 1
fi

echo "==> Downloading web/firebase_web_config.json..."
mkdir -p web
npx -y firebase-tools@latest apps:sdkconfig WEB "$WEB_APP_ID" --project "$PROJECT_ID" \
  > web/firebase_web_config.json

echo "==> Generating lib/firebase_options.dart..."
dart run tool/generate_firebase_options.dart

echo "==> Deploying Auth providers (email/password + Google)..."
npx -y firebase-tools@latest deploy --only auth --project "$PROJECT_ID"

echo "==> Deploying Firestore rules and indexes..."
npx -y firebase-tools@latest deploy --only firestore --project "$PROJECT_ID"

echo ""
echo "==> SHA-1 fingerprints for Google Sign-In:"
echo "    Debug (local flutter run):"
keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android 2>/dev/null \
  | grep -E 'SHA1|SHA-1' || echo "    (Run keytool manually if debug keystore is missing)"
echo ""
echo "    Play Store internal testing: add the App signing key SHA-1 from"
echo "    Play Console → Release → Setup → App integrity → App signing"
echo "    to Firebase Console → Project settings → Your apps → Add fingerprint."
echo ""
echo "Done."
echo "  Mobile: flutter run"
echo "  Web (local): flutter run -d chrome"
echo "  Web (deploy): bash scripts/deploy_web.sh"
