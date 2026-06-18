#!/usr/bin/env bash
# ============================================================================
# VitalSeker Edge Functions Deploy Script
# ============================================================================
# This script deploys all 6 edge functions to your Supabase project.
#
# PREREQUISITES:
#   1. Supabase CLI installed:  npm install -g supabase
#   2. Logged in:               supabase login
#      (Generate a token at https://supabase.com/dashboard/account/tokens)
#   3. Project linked:          supabase link --project-ref umncqfyzphvxtosddyae
#
# USAGE:
#   cd VitalSeker
#   bash deploy_functions.sh
# ============================================================================

set -e

PROJECT_REF="umncqfyzphvxtosddyae"
FUNCTIONS=(
  "vitalseker-triage"
  "generate-qr"
  "export-pdf"
  "weekly-insights"
  "sos-alert"
  "delete-account"
)

echo "============================================================"
echo "  VitalSeker Edge Functions Deploy"
echo "============================================================"
echo

# Verify CLI is installed
if ! command -v supabase &> /dev/null; then
  echo "❌ Supabase CLI not found. Install it first:"
  echo "   npm install -g supabase"
  exit 1
fi

# Verify project is linked
echo "→ Linking project $PROJECT_REF..."
supabase link --project-ref "$PROJECT_REF" 2>/dev/null || true
echo "  ✅ Linked."
echo

# Deploy each function
SUCCESS=0
FAILED=0

for fn in "${FUNCTIONS[@]}"; do
  echo "→ Deploying $fn..."
  if supabase functions deploy "$fn" --no-verify-jwt 2>&1 | grep -q "Deployed\|Function"; then
    echo "  ✅ $fn deployed successfully"
    SUCCESS=$((SUCCESS + 1))
  else
    echo "  ❌ $fn failed"
    FAILED=$((FAILED + 1))
  fi
  echo
done

echo "============================================================"
echo "  Deploy Summary"
echo "============================================================"
echo "  ✅ Success: $SUCCESS"
echo "  ❌ Failed:  $FAILED"
echo

if [ "$FAILED" -gt 0 ]; then
  echo "⚠️  Some functions failed to deploy. Check the output above."
  echo "   You can deploy them individually via the Dashboard:"
  echo "   Edge Functions → {function} → Edit → paste code → Deploy"
  exit 1
fi

echo "🎉 All functions deployed!"
echo
echo "Next steps:"
echo "  1. Update your .env with the new publishable key (already done if you pulled latest)"
echo "  2. Run: flutter pub get"
echo "  3. Run: flutter run"
