# VitalSeker Deployment Guide

> ⚠️ **SECURITY NOTICE**: This file previously contained a hardcoded
> `SUPABASE_SERVICE_KEY` (a service-role JWT with full admin privileges).
> That key has been **rotated and revoked**. If you find an old copy of this
> file in git history, treat the key as compromised — it must NOT be reused.
> Never commit secrets to the repository. Use `supabase secrets set` from
> your local machine instead.

## Edge Functions Deployment

The 5 Edge Functions need to be deployed to Supabase. Since the CLI requires a personal access token, follow these steps:

### Step 1: Install Supabase CLI
```bash
npm install -g supabase
```

### Step 2: Login to Supabase
```bash
supabase login
```
This will open a browser to generate a personal access token.

### Step 3: Link the Project
```bash
cd vitalseker
supabase link --project-ref umncqfyzphvxtosddyae
```

### Step 4: Deploy Each Edge Function
```bash
# AI Triage Function (requires GLM_GATEWAY_SECRET + GLM_GATEWAY_URL)
# Note: The project uses z.ai GLM-4-plus (substituted for Anthropic Claude per
# project owner's instruction). Set GLM_GATEWAY_SECRET and GLM_GATEWAY_URL.
supabase functions deploy vitalseker-triage

# Medical Translation Function (requires DEEPL_API_KEY — free dev tier offers
# 1M characters/month). Uses DeepL API for medical term translation.
supabase functions deploy translate

# QR Code Generation Function (requires QR_ENCRYPTION_KEY)
supabase functions deploy generate-qr

# PDF Export Function
supabase functions deploy export-pdf

# Weekly Insights Function (requires GLM_GATEWAY_SECRET + GLM_GATEWAY_URL + CRON_SECRET)
supabase functions deploy weekly-insights

# SOS Alert Function (requires TWILIO credentials)
supabase functions deploy sos-alert

# Account Deletion Function (required by GDPR / right to be forgotten)
supabase functions deploy delete-account
```

### Step 5: Set Environment Secrets

> ⚠️ Generate strong random values for `CRON_SECRET` and `QR_ENCRYPTION_KEY`.
> Do NOT reuse the service-role key as an encryption key.

```bash
# AI secrets — z.ai GLM gateway (substituted for Anthropic per project owner)
supabase secrets set GLM_GATEWAY_SECRET=your_glm_gateway_secret
supabase secrets set GLM_GATEWAY_URL=https://your-glm-gateway-url
# Optional: override the built-in triage system prompt
supabase secrets set TRIAGE_SYSTEM_PROMPT="your custom system prompt"

# Translation secrets — DeepL API (free dev tier: 1M chars/month)
# Get a free key at https://www.deepl.com/pro-api
supabase secrets set DEEPL_API_KEY=your_deepl_api_key

# SMS secrets — Twilio (for SOS alert messages)
supabase secrets set TWILIO_ACCOUNT_SID=your_twilio_account_sid
supabase secrets set TWILIO_AUTH_TOKEN=your_twilio_auth_token
supabase secrets set TWILIO_PHONE_NUMBER=your_twilio_phone_number

# Service role key — required by the weekly-insights cron job.
# This is the ONLY secret with admin privileges; rotate immediately if leaked.
supabase secrets set SUPABASE_SERVICE_KEY=your_service_role_jwt

# Cron secret — required header (x-cron-secret) for the weekly-insights
# function. Generate a strong random string:
#   openssl rand -base64 32
supabase secrets set CRON_SECRET=your_generated_cron_secret

# QR token encryption key — dedicated AES-256 key (NOT the service key).
# Generate a strong 32-byte base64 value:
#   openssl rand -base64 32
supabase secrets set QR_ENCRYPTION_KEY=your_generated_qr_key
```

### Step 5b: Set Client-Side Secrets (Flutter .env)

These secrets are loaded by the Flutter app at runtime. Set them in your
`.env` file (gitignored — never commit) or via `--dart-define` for CI/CD:

```bash
# Sentry (crash monitoring)
SENTRY_DSN=https://your_sentry_dsn@sentry.io/123

# OneSignal (push notifications)
ONESIGNAL_APP_ID=your-onesignal-app-id

# PostHog (analytics)
POSTHOG_API_KEY=phc_your_posthog_api_key
POSTHOG_HOST=https://us.i.posthog.com

# RevenueCat (in-app purchases)
REVENUECAT_API_KEY=appl_your_revenuecat_key
```

All of these are optional in development — the app runs in no-op mode
without them. They MUST be set for production deployment.

### Step 6: Configure CRON for Weekly Insights
In the Supabase Dashboard → Database → Cron Jobs, add a schedule that invokes
the weekly-insights function **with the `x-cron-secret` header** so the
function's auth gate passes:

```sql
SELECT cron.schedule(
  'weekly-insights-cron',
  '0 8 * * 1',  -- Every Monday at 08:00 UTC
  $$
  SELECT net.http_post(
    url := 'https://umncqfyzphvxtosddyae.supabase.co/functions/v1/weekly-insights',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', '<paste your CRON_SECRET value here>'
    ),
    body := '{}'::jsonb
  );
  $$
);
```

> Replace `<paste your CRON_SECRET value here>` with the same string you set
> via `supabase secrets set CRON_SECRET=...`. Without this header the function
> returns `401 Unauthorized`.

### Step 7: Apply the security-hardening migration
```bash
supabase db push
# or, manually via the SQL editor:
#   apply supabase/migrations/004_security_hardening.sql
```
This migration:
- Adds `UNIQUE (user_id)` on `health_passports` (fixes silent upsert failures).
- Replaces the open `WITH CHECK (true)` policies on `weekly_insights` with
  service-role-only INSERT/UPDATE (closes the cross-user write hole).
- Adds missing DELETE policies on `weekly_insights` and `subscriptions`.
- Adds `updated_at` auto-touch triggers on `users`, `health_passports`,
  `medications`, `appointments`, `subscriptions`.

## Auth Configuration

### Enable Auth Providers (Supabase Dashboard → Authentication → Providers)
1. **Email/Password**: Enabled by default
2. **Google OAuth**:
   - Go to Google Cloud Console → Create OAuth 2.0 Client
   - Add redirect URL: `https://umncqfyzphvxtosddyae.supabase.co/auth/v1/callback`
   - Enter Client ID and Secret in Supabase
3. **Apple Sign-In**:
   - Configure in Apple Developer Portal
   - Enter Service ID, Team ID, Key ID, and Private Key in Supabase

## Flutter Setup

### 1. Install Dependencies
```bash
cd vitalseker
flutter pub get
```

### 2. Create .env File
Create a `.env` file at the project root (gitignored) with your Supabase
**anon** key (NOT the service-role key):

```
SUPABASE_URL=https://umncqfyzphvxtosddyae.supabase.co
SUPABASE_ANON_KEY=your_anon_key_here
```

### 3. Add Fonts
Place your font files in `assets/fonts/`:
- ClashDisplay-Regular.otf, ClashDisplay-Medium.otf, ClashDisplay-Semibold.otf, ClashDisplay-Bold.otf
- Outfit-Regular.ttf, Outfit-Medium.ttf, Outfit-SemiBold.ttf, Outfit-Bold.ttf
- Inter-Regular.ttf, Inter-Medium.ttf, Inter-SemiBold.ttf, Inter-Bold.ttf
- DMSans-Regular.ttf, DMSans-Medium.ttf, DMSans-Bold.ttf
- JetBrainsMono-Regular.ttf, JetBrainsMono-Medium.ttf, JetBrainsMono-Bold.ttf

### 4. Run the App
```bash
flutter run
```

## Google Sign-In Setup (Android)
1. Get your SHA-1 fingerprint: `keytool -list -v -keystore ~/.android/debug.keystore`
2. Add to Firebase/Google Cloud Console
3. Add the `google-services.json` to `android/app/`

## Apple Sign-In Setup (iOS)
1. Enable "Sign in with Apple" capability in Xcode
2. Configure in Apple Developer Portal
