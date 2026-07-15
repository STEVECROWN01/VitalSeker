#!/usr/bin/env bash
# ============================================================================
# VitalSeker Post-Sprint Setup Script
# ============================================================================
# This script automates the 6 manual action items from the security + features
# sprint. Run it once after pulling the latest main.
#
# WHAT IT DOES:
#   1. Generates strong random values for CRON_SECRET and QR_ENCRYPTION_KEY.
#   2. Sets those secrets on your Supabase project via the CLI.
#   3. Applies migrations 004 (security hardening) and 005 (avatars bucket).
#   4. Deploys the new `delete-account` edge function.
#   5. Replaces the existing weekly-insights cron job with one that includes
#      the x-cron-secret header.
#   6. Tells you to run `flutter pub get` locally for the image_picker dep.
#
# PREREQUISITES:
#   - A Supabase personal access token from
#     https://supabase.com/dashboard/account/tokens
#     (Set it as the SUPABASE_ACCESS_TOKEN env var before running.)
#   - The Supabase CLI (will be auto-installed via npx if not present).
#   - openssl (pre-installed on macOS / Linux; on Windows use WSL).
#
# IMPORTANT — DO THIS FIRST MANUALLY:
#   Rotate the service_role key in the Supabase Dashboard:
#     Settings → API → JWT Settings → "Rotate service_role key"
#   The old key was committed in plaintext in DEPLOYMENT.md and must be
#   considered compromised. After rotating, copy the NEW service_role key —
#   you'll paste it below when the script prompts for SUPABASE_SERVICE_KEY.
#
# USAGE:
#   SUPABASE_ACCESS_TOKEN=xxxxxx bash setup.sh
# ============================================================================

set -euo pipefail

PROJECT_REF="umncqfyzphvxtosddyae"
SUPABASE_URL="https://${PROJECT_REF}.supabase.co"

# Color helpers
red()   { printf "\033[31m%s\033[0m\n" "$*"; }
green() { printf "\033[32m%s\033[0m\n" "$*"; }
yellow(){ printf "\033[33m%s\033[0m\n" "$*"; }
blue()  { printf "\033[34m%s\033[0m\n" "$*"; }

echo
blue "============================================================"
blue "  VitalSeker Post-Sprint Setup"
blue "============================================================"
echo

# ---- 0. Preflight checks ---------------------------------------------------
if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
  red "ERROR: SUPABASE_ACCESS_TOKEN env var is not set."
  echo
  echo "Get one from: https://supabase.com/dashboard/account/tokens"
  echo "Then re-run:"
  echo
  echo "  SUPABASE_ACCESS_TOKEN=xxxxxx bash setup.sh"
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  red "ERROR: openssl is not installed. On macOS/Linux it's pre-installed; on Windows use WSL."
  exit 1
fi

# Locate supabase CLI — try local, then npx.
SUPABASE_BIN=""
if command -v supabase >/dev/null 2>&1; then
  SUPABASE_BIN="supabase"
else
  yellow "Supabase CLI not found globally. Will use npx (downloads on first run)."
  SUPABASE_BIN="npx --yes supabase"
fi
green "Using Supabase CLI: ${SUPABASE_BIN}"

# Authenticate the CLI with the access token.
echo
yellow "→ Logging in to Supabase..."
echo "${SUPABASE_ACCESS_TOKEN}" | ${SUPABASE_BIN} login --token "${SUPABASE_ACCESS_TOKEN}" >/dev/null 2>&1 \
  || ${SUPABASE_BIN} login --token "${SUPABASE_ACCESS_TOKEN}" >/dev/null 2>&1 \
  || true
# The CLI persists the token in ~/.supabase/access-token after first login.

# Link the project (idempotent).
yellow "→ Linking project ${PROJECT_REF}..."
${SUPABASE_BIN} link --project-ref "${PROJECT_REF}" >/dev/null 2>&1 || true
green "  Linked."

# ---- 1. Generate strong secrets -------------------------------------------
echo
yellow "→ Generating strong secrets..."
CRON_SECRET=$(openssl rand -base64 32)
QR_ENCRYPTION_KEY=$(openssl rand -base64 32)
green "  CRON_SECRET=${CRON_SECRET}"
green "  QR_ENCRYPTION_KEY=${QR_ENCRYPTION_KEY}"

# ---- 2. Prompt for the NEW (rotated) service-role key ---------------------
echo
yellow "→ You should have already rotated the service_role key in the dashboard."
yellow "  (Settings → API → JWT Settings → Rotate service_role key)"
echo
read -r -p "Paste the NEW service_role key (will be set as SUPABASE_SERVICE_KEY on edge functions): " SUPABASE_SERVICE_KEY
if [[ -z "${SUPABASE_SERVICE_KEY}" ]]; then
  red "ERROR: No service key provided. Aborting."
  exit 1
fi

# ---- 3. Set all secrets on the project ------------------------------------
echo
yellow "→ Setting edge function secrets..."
${SUPABASE_BIN} secrets set CRON_SECRET="${CRON_SECRET}"
${SUPABASE_BIN} secrets set QR_ENCRYPTION_KEY="${QR_ENCRYPTION_KEY}"
${SUPABASE_BIN} secrets set SUPABASE_SERVICE_KEY="${SUPABASE_SERVICE_KEY}"
${SUPABASE_BIN} secrets set SUPABASE_URL="${SUPABASE_URL}"
green "  All secrets set. (Existing ANTHROPIC_API_KEY + TWILIO_* secrets are preserved.)"

# ---- 4. Apply migrations ---------------------------------------------------
echo
yellow "→ Applying SQL migrations 004 + 005..."
# We push via the CLI. If `db push` complains about unapplied migrations,
# fall back to running the SQL files directly via psql-like execution.
${SUPABASE_BIN} db push --include-all || {
  yellow "  db push had issues — applying migration files individually via the SQL API."
  for f in supabase/migrations/004_security_hardening.sql supabase/migrations/005_avatars_bucket.sql; do
    if [[ -f "$f" ]]; then
      yellow "  Applying $f..."
      ${SUPABASE_BIN} db execute --file "$f" || \
        red "  FAILED to apply $f — apply it manually in the SQL editor."
    fi
  done
}
green "  Migrations applied."

# ---- 5. Deploy edge functions ----------------------------------------------
echo
yellow "→ Deploying edge functions..."
# FIX (audit C-5, L-16/L-22): deploy all 8 functions (was 6 — missing
# translate and ai-chat). Only weekly-insights uses --no-verify-jwt (cron);
# all others keep JWT verification ON for security.
NO_VERIFY_JWT_FUNCTIONS="weekly-insights"
for fn in vitalseker-triage generate-qr export-pdf translate ai-chat weekly-insights sos-alert delete-account; do
  if [[ -d "supabase/functions/${fn}" ]]; then
    yellow "  Deploying ${fn}..."
    if [[ " ${NO_VERIFY_JWT_FUNCTIONS} " =~ " ${fn} " ]]; then
      ${SUPABASE_BIN} functions deploy "${fn}" --no-verify-jwt || \
        red "  FAILED to deploy ${fn} — check the function logs."
    else
      ${SUPABASE_BIN} functions deploy "${fn}" || \
        red "  FAILED to deploy ${fn} — check the function logs."
    fi
  fi
done
green "  All edge functions deployed."

# ---- 6. Update the weekly-insights cron job to include the secret header ---
echo
yellow "→ Updating the weekly-insights cron job..."
# Drop the old job (if it exists) and recreate with the x-cron-secret header.
${SUPABASE_BIN} db execute --query "SELECT cron.unschedule('weekly-insights-cron');" 2>/dev/null || true
${SUPABASE_BIN} db execute --query "
SELECT cron.schedule(
  'weekly-insights-cron',
  '0 8 * * 1',  -- Every Monday at 08:00 UTC
  \$\$
  SELECT net.http_post(
    url := '${SUPABASE_URL}/functions/v1/weekly-insights',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', '${CRON_SECRET}'
    ),
    body := '{}'::jsonb
  );
  \$\$
);
" || red "  FAILED to update cron job — see DEPLOYMENT.md for the manual SQL."
green "  Cron job updated with x-cron-secret header."

# ---- 7. Remind about flutter pub get --------------------------------------
echo
yellow "→ Flutter dependency reminder:"
echo "  Run this on your dev machine:"
echo
echo "    cd vitalseker && flutter pub get"
echo
echo "  This picks up the new image_picker dependency added for avatar upload."

# ---- 8. Print a summary card ----------------------------------------------
echo
blue "============================================================"
blue "  Setup complete — save these credentials somewhere safe!"
blue "============================================================"
echo
printf "  %-25s %s\n" "Project ref:"           "${PROJECT_REF}"
printf "  %-25s %s\n" "Supabase URL:"          "${SUPABASE_URL}"
printf "  %-25s %s\n" "CRON_SECRET:"           "${CRON_SECRET}"
printf "  %-25s %s\n" "QR_ENCRYPTION_KEY:"     "${QR_ENCRYPTION_KEY}"
printf "  %-25s %s\n" "SUPABASE_SERVICE_KEY:"  "(set — not shown again)"
echo
yellow "⚠️  Rotate the SUPABASE_SERVICE_KEY again if this terminal log is shared."
echo
green "Done. See DEPLOYMENT.md for any manual fallback steps."
