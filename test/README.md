# VitalSeker Test Plan

The `test/` directory contains pure-Dart unit tests that don't require a
running device. These cover the regression surface for the bugs fixed in the
recent hardening sprint, plus the router redirect logic and provider
mutations.

## Running tests

```bash
flutter test
```

Or to run a single suite:

```bash
flutter test test/user_profile_model_test.dart
```

## What's covered

### `test/widget_test.dart` (existing)
Smoke test: pumps `VitalSekerApp` and verifies the splash screen renders
the app name. Does NOT cover the full auth/onboarding flow.

### `test/user_profile_model_test.dart`
- Round-trip serialization of all UserProfile fields including the new
  `gender`, `height_cm`, `weight_kg`, `notification_prefs` extension
  columns added in migration 003.
- Tolerance for missing extension fields (back-compat with databases that
  haven't yet applied migration 003).
- `NotificationPrefs` defaults + `copyWith`.
- `UserProfile.copyWith` preserves immutable fields (id, email, createdAt)
  and bumps `updatedAt`.

### `test/app_snack_bar_test.dart`
- `AppSnackBar.error` / `.success` / `.info` render the correct icon and
  message.
- `AppSnackBar.errorFromException` shows the friendly message and does NOT
  leak the raw exception string to the UI (logs it via debugPrint only).

### `test/vitals_window_test.dart`
- `VitalType` enum exposes all 7 expected values with non-empty display
  name, unit, color, and icon.
- Vital `displayValue` includes systolic/diastolic for blood pressure.
- The segment-window filtering logic that the VitalsScreen Day/Week/Month
  control relies on. Verifies that the 1-day, 7-day, and 30-day windows
  include exactly the expected subset of readings — guards against the
  cosmetic-filter regression that this sprint fixed.

### `test/app_config_test.dart`
- All ~33 route path constants are unique, start with `/`, and live under
  the correct prefix (`/login` etc. for public routes, `/home/*` for
  protected routes that the router's auth gate must protect).

### `test/router_redirect_test.dart`
- **Comprehensive auth-gate coverage** for every route in the app, across
  all three auth states: unauthenticated, authenticated + onboarding
  complete, authenticated + onboarding NOT complete (the security gap we
  fixed in this sprint).
- Sign-in flow simulation: unauthenticated → authed-without-onboarding →
  authed-with-onboarding, verifying the redirect target at each step.
- Sign-out flow simulation: authed → unauthenticated, verifying the
  redirect kicks in to send the user back to onboarding.
- Provider wiring sanity checks: confirms that overridden
  `isAuthenticatedProvider` and `isOnboardingCompletedProvider` values
  actually flow through the Riverpod container to the redirect logic.

### `test/providers_unit_test.dart`
- **MedicationsNotifier**: build() loads from DB; addMedication() inserts
  with correct payload + triggers cache invalidation (verified by counting
  getMedications calls); updateMedicationStatus(); deleteMedication();
  updateMedicationDetails() sends all editable fields.
- **VitalsNotifier**: build() loads; addVital() for blood pressure includes
  value_secondary; deleteVital().
- **AppointmentsNotifier**: build() loads; addAppointment() inserts with
  correct doctor_name/specialty/location; **rescheduleAppointment()**
  (the new method added in the reschedule feature) updates date_time AND
  resets status to 'upcoming'; updateAppointmentStatus();
  deleteAppointment().
- **Null-user guard**: all three notifiers return empty lists (and skip
  the DB call) when `currentUserProvider` is null.

  All tests use a `FakeDatabaseService` that records every call so we can
  assert on the exact method + arguments, plus a `FakeUser` that uses
  `noSuchMethod` so we don't have to stub every field on the real Supabase
  User class.

## What's NOT yet covered (future work)

- **Widget-level integration tests** for the auth flow (login → dashboard
  transition, register → onboarding, sign-out → login).
- **Edge function Deno tests**: the cron-secret gate on `weekly-insights`,
  the AES key handling on `generate-qr`, the prompt-injection guards on
  `triage`, the rate limiting on `sos-alert`, the email-confirmation gate
  on `delete-account`.
- **End-to-end / integration_test/ tests**: full sign-up → onboarding →
  add vital → view history → trigger SOS flow on a device.
- **Storage RLS tests**: verifying that the avatars bucket policy actually
  rejects cross-user writes (would need a second test user).

These should be added in a follow-up PR.
