# VitalSeker Test Plan

The `test/` directory contains pure-Dart unit tests that don't require a
running device. These cover the regression surface for the bugs fixed in the
recent hardening sprint.

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
- **The segment-window filtering logic** that the VitalsScreen Day/Week/Month
  control relies on. Verifies that the 1-day, 7-day, and 30-day windows
  include exactly the expected subset of readings — guards against the
  cosmetic-filter regression that this sprint fixed.

### `test/app_config_test.dart`
- All ~33 route path constants are unique, start with `/`, and live under
  the correct prefix (`/login` etc. for public routes, `/home/*` for
  protected routes that the router's auth gate must protect).

## What's NOT yet covered (future work)

- **Router redirect logic**: a widget test that pumps `MaterialApp.router`
  with a mocked `isAuthenticatedProvider` and verifies redirects to
  `/onboarding` / `/login` / `/dashboard` on each auth-state transition.
- **Provider unit tests**: `MedicationsNotifier.addMedication` /
  `VitalsNotifier.addVital` / `AppointmentsNotifier.addAppointment` with a
  mocked `DatabaseService`.
- **Edge function tests**: Deno tests for the `weekly-insights` cron-secret
  gate, the `generate-qr` AES key handling, and the `triage` prompt
  injection guards.
- **Integration tests** (`integration_test/`): full sign-up → onboarding →
  add vital → view history → trigger SOS flow on a device.

These should be added in a follow-up PR.
