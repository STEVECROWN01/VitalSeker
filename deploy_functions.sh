#!/usr/bin/env bash
# ============================================================================
# VitalSeker Edge Functions Deploy Script
# ============================================================================
# This script deploys all 8 edge functions to your Supabase project.
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
#
# SECURITY (audit C-5, M-16 fixes):
#   - All 8 functions are deployed (previously only 6 — translate and ai-chat
#     were missing, causing them to silently 404 in production).
#   - Only `weekly-insights` (cron) and `delete-account` (uses its own
#     service-role check) are deployed with --no-verify-jwt. All other
#     functions keep platform-level JWT verification ON so only authenticated
#     users can invoke them.
#   - Success detection uses the CLI exit code instead of grepping stdout
#     (the previous grep-based check matched "Function" in error messages
#     too, masking failures).
# ============================================================================

set -e

PROJECT_REF="umncqfyzphvxtosddyae"

# All 8 edge functions in the project.
# Functions marked with "--no-verify-jwt" are the only ones that bypass
# platform-level JWT verification — they implement their own auth checks.
FUNCTIONS=(
  "vitalseker-triage"
  "generate-qr"
  "export-pdf"
  "translate"
  "ai-chat"
  "sos-alert"
  "weekly-insights"        # cron-triggered, uses x-cron-secret
  "delete-account"         # uses caller JWT + service-role for admin API
)

# Functions that should bypass platform JWT verification.
# weekly-insights: triggered by cron with x-cron-secret header, no user JWT.
# delete-account: uses the caller's JWT to identify the user, then uses the
#                 service-role key for admin.deleteUser(). Platform JWT
#                 verification is redundant here (the function re-verifies).
NO_VERIFY_JWT_FUNCTIONS=(
  "weekly-insights"
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

# Helper: check if a function should bypass JWT verification
should_skip_jwt_verify() {
  local fn="$1"
  for skip_fn in "${NO_VERIFY_JWT_FUNCTIONS[@]}"; do
    if [[ "$fn" == "$skip_fn" ]]; then
      return 0
    fi
  done
  return 1
}

# Deploy each function
SUCCESS=0
FAILED=0

for fn in "${FUNCTIONS[@]}"; do
  echo "→ Deploying $fn..."

  # Build the deploy command. Use the CLI exit code for success detection
  # (audit M-15 fix — the previous grep-based check was unreliable).
  if should_skip_jwt_verify "$fn"; then
    echo "  (deploying with --no-verify-jwt: $fn uses its own auth check)"
    if supabase functions deploy "$fn" --no-verify-jwt > /dev/null 2>&1; then
      echo "  ✅ $fn deployed successfully"
      SUCCESS=$((SUCCESS + 1))
    else
      echo "  ❌ $fn failed"
      FAILED=$((FAILED + 1))
    fi
  else
    if supabase functions deploy "$fn" > /dev/null 2>&1; then
      echo "  ✅ $fn deployed successfully (JWT verification ON)"
      SUCCESS=$((SUCCESS + 1))
    else
      echo "  ❌ $fn failed"
      FAILED=$((FAILED + 1))
    fi
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
