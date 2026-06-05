# VitalSeker Deployment Guide

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
# AI Triage Function (requires ANTHROPIC_API_KEY)
supabase functions deploy vitalseker-triage

# QR Code Generation Function
supabase functions deploy generate-qr

# PDF Export Function
supabase functions deploy export-pdf

# Weekly Insights Function (requires ANTHROPIC_API_KEY)
supabase functions deploy weekly-insights

# SOS Alert Function (requires TWILIO credentials)
supabase functions deploy sos-alert
```

### Step 5: Set Environment Secrets
```bash
supabase secrets set ANTHROPIC_API_KEY=your_anthropic_api_key
supabase secrets set TWILIO_ACCOUNT_SID=your_twilio_account_sid
supabase secrets set TWILIO_AUTH_TOKEN=your_twilio_auth_token
supabase secrets set TWILIO_PHONE_NUMBER=your_twilio_phone_number
supabase secrets set SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVtbmNxZnl6cGh2eHRvc2RkeWFlIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0ODgyOTI5NSwiZXhwIjoyMDY0NDA1Mjk1fQ.cVkKxPP_7Nb1c8qfRvmV-0e6iHYrVYgWXz7A3T8U0vs
```

### Step 6: Configure CRON for Weekly Insights
In the Supabase Dashboard → Database → Cron Jobs, add:
```sql
SELECT cron.schedule(
  'weekly-insights-cron',
  '0 8 * * 1',  -- Every Monday at 08:00 UTC
  $$
  SELECT net.http_post(
    url := 'https://umncqfyzphvxtosddyae.supabase.co/functions/v1/weekly-insights',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('request.jwt.claims')::json->>'role',
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);
```

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
The `.env` file is already configured with your Supabase credentials:
```
SUPABASE_URL=https://umncqfyzphvxtosddyae.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
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
