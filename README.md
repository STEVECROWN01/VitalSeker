# VitalSeker

**Your AI Health Companion** — a Flutter mobile app combining AI-powered symptom triage with a digital medical passport.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Backend-Supabase-green)](https://supabase.com)

## What is VitalSeker?

VitalSeker solves three problems in one product:

1. **AI Symptom Triage** — A 5-question flow in 90 seconds returns a green/yellow/red urgency level with a clear recommended action. Powered by GLM-4 (substituted for Anthropic Claude per project owner's instruction).
2. **Digital Medical Passport** — Encrypted QR code (24h TTL) shareable with any healthcare professional worldwide, working offline.
3. **Emergency SOS** — One-tap sends passport + GPS location to emergency contacts via SMS.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI/UX Design | Google Stitch AI |
| Mobile App | Flutter (Dart) |
| Backend | Supabase (Postgres + Edge Functions + Storage) |
| AI Engine | z.ai GLM-4-plus (substituted for Claude) |
| Translation | DeepL API (free dev tier — 1M chars/month) |
| SMS | Twilio |
| State Management | Riverpod |
| Routing | GoRouter |
| Auth | Supabase Auth (Email + Google + Apple) |

## Getting Started

### Prerequisites

- Flutter 3.x stable (currently 3.44.3)
- Dart 3.12+
- A Supabase project (or use the hardcoded defaults in `lib/core/config/supabase_config.dart`)

### Installation

```bash
git clone https://github.com/STEVECROWN01/VitalSeker.git
cd VitalSeker
flutter pub get
flutter run
```

### Environment

The `.env` file is optional — defaults are hardcoded in `lib/core/config/`. To override:

```bash
cp .env .env.local  # then edit values
```

## Project Structure

```
lib/
├── core/
│   ├── config/         # App + Supabase configuration
│   ├── models/         # Data models (JSON serializable)
│   ├── providers/      # Riverpod state providers
│   ├── router/         # GoRouter configuration
│   └── services/       # Auth, Database, Edge Function services
├── features/
│   ├── appointments/   # Doctor appointment scheduling
│   ├── auth/           # Login + Register screens
│   ├── dashboard/      # Home dashboard
│   ├── export/         # PDF export (Pro)
│   ├── family/         # Family profiles (Pro, up to 5)
│   ├── health/         # Health summary screen
│   ├── history/        # Symptom log history
│   ├── insights/       # AI weekly insights (Pro)
│   ├── medications/    # Medication tracking
│   ├── onboarding/     # 3-slide onboarding
│   ├── passport/       # Medical passport + QR
│   ├── profile/        # Profile + Settings sub-tree
│   ├── splash/         # Loading splash
│   ├── sos/            # Emergency SOS
│   ├── triage/         # AI symptom triage
│   └── vitals/         # Vitals logging (HR, BP, SpO2, etc.)
├── l10n/               # 26 .arb localization files
└── shared/
    ├── theme/          # AppColors, AppTextStyles, AppTheme
    └── widgets/        # Reusable widgets (snackbars, disclaimers, etc.)

supabase/
├── functions/          # 7 Edge Functions (triage, translate, generate-qr, etc.)
└── migrations/         # 7 SQL migrations (schema + RLS)
```

## Subscription Tiers

| Tier | Price | Features |
|------|-------|----------|
| Free | $0 | 3 triages/month, basic passport, QR emergency, 26 languages |
| Pro | $6.99/mo | Unlimited triages, full history, PDF export, 5 family profiles, weekly AI insights |
| Enterprise | $199/mo | Clinical dashboard, EHR API, white-label, priority support |

## Deployment

See [DEPLOYMENT.md](DEPLOYMENT.md) for full Supabase setup, edge function deployment, and secret configuration.

## Localization

The app supports 26 locales. English is the baseline (615 message keys). Other locales have varying coverage — see `lib/l10n/` for the current state. To regenerate localization files after editing `.arb` files:

```bash
flutter gen-l10n
```

## Testing

```bash
flutter test
```

## License

Proprietary — Produced by Keter Marketing for VitalSeker.

## Acknowledgements

- Design: Google Stitch AI
- Backend: Supabase
- AI: z.ai GLM-4-plus
- Translation: DeepL
