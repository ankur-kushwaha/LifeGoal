#!/usr/bin/env bash
# Build Flutter web and deploy to Firebase Hosting on the same project.
set -euo pipefail

PROJECT_ID="${FIREBASE_PROJECT:-mymaps-b534f}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT_DIR"

echo "==> Using Firebase project: $PROJECT_ID"
npx -y firebase-tools@latest use "$PROJECT_ID"

echo "==> Building Flutter web (release)..."
flutter pub get
flutter build web --release

echo "==> Deploying to Firebase Hosting..."
npx -y firebase-tools@latest deploy --only hosting --project "$PROJECT_ID"

echo ""
echo "Done. Your web app should be live at:"
echo "  https://${PROJECT_ID}.web.app"
echo "  https://${PROJECT_ID}.firebaseapp.com"
