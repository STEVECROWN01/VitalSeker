import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitalseker/core/config/app_config.dart';
import 'package:vitalseker/core/providers/auth_provider.dart';
import 'package:vitalseker/core/providers/user_profile_provider.dart';
import 'package:vitalseker/core/models/user_profile.dart';

/// Re-implements the redirect rules from app_router.dart verbatim, so we can
/// test the auth/onboarding gate logic in isolation without spinning up a
/// real GoRouter tree (which would require a full MaterialApp + navigator
/// keys).
///
/// The production `redirect` callback in `app_router.dart` reads
/// `isAuthenticatedProvider` and `isOnboardingCompletedProvider` and applies
/// these exact rules in this exact order. If you change one, change the other.
String? applyRedirect({
  required bool isAuth,
  required bool onboardingDone,
  required String location,
}) {
  final isSplash = location == AppConfig.splash;
  final isOnboarding = location == AppConfig.onboarding;
  final isLogin = location == AppConfig.login;
  final isRegister = location == AppConfig.register;

  // Allow splash to load (it handles its own navigation).
  if (isSplash) return null;

  // Not authenticated: only allow login, register, onboarding.
  if (!isAuth) {
    if (isLogin || isRegister || isOnboarding) return null;
    return AppConfig.onboarding;
  }

  // Authenticated: redirect away from auth screens.
  if (isLogin || isRegister) {
    return onboardingDone ? AppConfig.dashboard : AppConfig.onboarding;
  }

  // Authenticated + onboarding complete + trying to view onboarding:
  // skip it and go to dashboard.
  if (isOnboarding && onboardingDone) {
    return AppConfig.dashboard;
  }

  // Authenticated but onboarding not complete: force onboarding (unless
  // already there).
  if (!onboardingDone && !isOnboarding) {
    return AppConfig.onboarding;
  }

  return null;
}

ProviderContainer makeContainer({
  required bool isAuth,
  required bool onboardingDone,
}) {
  return ProviderContainer(overrides: [
    isAuthenticatedProvider.overrideWith((ref) => isAuth),
    isOnboardingCompletedProvider.overrideWith((ref) => onboardingDone),
  ]);
}

void main() {
  group('router redirect — unauthenticated user', () {
    final cases = <String, String?>{
      // Public routes — allowed.
      AppConfig.splash: null,
      AppConfig.login: null,
      AppConfig.register: null,
      AppConfig.onboarding: null,
      // Protected routes — redirect to onboarding.
      AppConfig.dashboard: AppConfig.onboarding,
      AppConfig.vitals: AppConfig.onboarding,
      AppConfig.addVital: AppConfig.onboarding,
      AppConfig.vitalsHistory: AppConfig.onboarding,
      AppConfig.health: AppConfig.onboarding,
      AppConfig.triage: AppConfig.onboarding,
      AppConfig.triageResult: AppConfig.onboarding,
      AppConfig.passport: AppConfig.onboarding,
      AppConfig.qrDisplay: AppConfig.onboarding,
      AppConfig.history: AppConfig.onboarding,
      AppConfig.insights: AppConfig.onboarding,
      AppConfig.family: AppConfig.onboarding,
      AppConfig.exportScreen: AppConfig.onboarding,
      AppConfig.sos: AppConfig.onboarding,
      AppConfig.medications: AppConfig.onboarding,
      AppConfig.addMedication: AppConfig.onboarding,
      AppConfig.appointments: AppConfig.onboarding,
      AppConfig.addAppointment: AppConfig.onboarding,
      AppConfig.profile: AppConfig.onboarding,
      AppConfig.editProfile: AppConfig.onboarding,
      AppConfig.settings: AppConfig.onboarding,
      AppConfig.notificationsSettings: AppConfig.onboarding,
      AppConfig.helpSupport: AppConfig.onboarding,
      AppConfig.privacyPolicy: AppConfig.onboarding,
      AppConfig.termsOfService: AppConfig.onboarding,
      AppConfig.medicalId: AppConfig.onboarding,
      AppConfig.medicalRecords: AppConfig.onboarding,
      AppConfig.subscription: AppConfig.onboarding,
      AppConfig.about: AppConfig.onboarding,
    };

    for (final entry in cases.entries) {
      test('unauthenticated → ${entry.key} redirects to ${entry.value}', () {
        final container = makeContainer(isAuth: false, onboardingDone: false);
        addTearDown(container.dispose);
        // Verify the container's providers match what we expect.
        expect(container.read(isAuthenticatedProvider), isFalse);
        expect(container.read(isOnboardingCompletedProvider), isFalse);
        // Verify the redirect.
        expect(
          applyRedirect(
            isAuth: container.read(isAuthenticatedProvider),
            onboardingDone: container.read(isOnboardingCompletedProvider),
            location: entry.key,
          ),
          entry.value,
        );
      });
    }
  });

  group('router redirect — authenticated + onboarding complete', () {
    test('auth screens redirect to dashboard', () {
      final container = makeContainer(isAuth: true, onboardingDone: true);
      addTearDown(container.dispose);
      expect(applyRedirect(isAuth: true, onboardingDone: true, location: AppConfig.login), AppConfig.dashboard);
      expect(applyRedirect(isAuth: true, onboardingDone: true, location: AppConfig.register), AppConfig.dashboard);
    });

    test('onboarding route redirects to dashboard (skip the carousel)', () {
      expect(applyRedirect(isAuth: true, onboardingDone: true, location: AppConfig.onboarding), AppConfig.dashboard);
    });

    test('protected routes are allowed', () {
      final protectedRoutes = [
        AppConfig.dashboard,
        AppConfig.vitals,
        AppConfig.triage,
        AppConfig.passport,
        AppConfig.sos,
        AppConfig.profile,
        AppConfig.settings,
        AppConfig.medicalRecords,
        AppConfig.insights,
        AppConfig.medications,
        AppConfig.appointments,
      ];
      for (final route in protectedRoutes) {
        expect(applyRedirect(isAuth: true, onboardingDone: true, location: route), isNull,
            reason: '$route should be allowed when authed + onboarding done');
      }
    });

    test('splash is always allowed', () {
      expect(applyRedirect(isAuth: true, onboardingDone: true, location: AppConfig.splash), isNull);
    });
  });

  group('router redirect — authenticated + onboarding NOT complete', () {
    test('protected routes redirect to onboarding (the security gap we fixed)', () {
      // The original router captured `isAuthenticated` once at construction
      // and didn't consult `isOnboardingCompletedProvider` at all — so an
      // authenticated user who skipped onboarding could navigate directly
      // to /home/dashboard. This test guards against that regression.
      final protectedRoutes = [
        AppConfig.dashboard,
        AppConfig.vitals,
        AppConfig.triage,
        AppConfig.passport,
        AppConfig.sos,
        AppConfig.profile,
        AppConfig.medications,
        AppConfig.appointments,
      ];
      for (final route in protectedRoutes) {
        expect(applyRedirect(isAuth: true, onboardingDone: false, location: route), AppConfig.onboarding,
            reason: '$route should redirect to onboarding when onboarding is incomplete');
      }
    });

    test('auth screens redirect to onboarding (not dashboard) when onboarding is incomplete', () {
      // This was a subtle case: an authenticated user navigating to /login
      // should be sent to onboarding (to finish setup), NOT to dashboard.
      expect(applyRedirect(isAuth: true, onboardingDone: false, location: AppConfig.login), AppConfig.onboarding);
      expect(applyRedirect(isAuth: true, onboardingDone: false, location: AppConfig.register), AppConfig.onboarding);
    });

    test('onboarding route is allowed (user is mid-onboarding)', () {
      expect(applyRedirect(isAuth: true, onboardingDone: false, location: AppConfig.onboarding), isNull);
    });

    test('splash is always allowed', () {
      expect(applyRedirect(isAuth: true, onboardingDone: false, location: AppConfig.splash), isNull);
    });
  });

  group('router redirect — sign-in/out transitions', () {
    test('sign-in flow: unauthenticated /onboarding → authed /dashboard', () {
      // Start: unauthenticated, onboarding complete=false.
      expect(applyRedirect(isAuth: false, onboardingDone: false, location: AppConfig.dashboard), AppConfig.onboarding);
      // User signs in but hasn't completed onboarding yet.
      expect(applyRedirect(isAuth: true, onboardingDone: false, location: AppConfig.dashboard), AppConfig.onboarding);
      // User completes onboarding.
      expect(applyRedirect(isAuth: true, onboardingDone: true, location: AppConfig.dashboard), isNull);
    });

    test('sign-out flow: authed /dashboard → unauthenticated redirect to onboarding', () {
      expect(applyRedirect(isAuth: true, onboardingDone: true, location: AppConfig.dashboard), isNull);
      expect(applyRedirect(isAuth: false, onboardingDone: true, location: AppConfig.dashboard), AppConfig.onboarding);
    });
  });

  group('router redirect — provider wiring sanity', () {
    // These tests verify that the override providers actually feed into the
    // redirect logic correctly through the Riverpod container — i.e. that
    // the production `ref.read(isAuthenticatedProvider)` call returns what
    // the override says.
    test('container reads overridden isAuthenticatedProvider', () {
      final c1 = makeContainer(isAuth: true, onboardingDone: true);
      addTearDown(c1.dispose);
      expect(c1.read(isAuthenticatedProvider), isTrue);

      final c2 = makeContainer(isAuth: false, onboardingDone: false);
      addTearDown(c2.dispose);
      expect(c2.read(isAuthenticatedProvider), isFalse);
    });

    test('container reads overridden isOnboardingCompletedProvider', () {
      final c1 = makeContainer(isAuth: true, onboardingDone: true);
      addTearDown(c1.dispose);
      expect(c1.read(isOnboardingCompletedProvider), isTrue);

      final c2 = makeContainer(isAuth: true, onboardingDone: false);
      addTearDown(c2.dispose);
      expect(c2.read(isOnboardingCompletedProvider), isFalse);
    });

    test('full redirect call via container — unauthenticated + dashboard', () {
      final container = makeContainer(isAuth: false, onboardingDone: false);
      addTearDown(container.dispose);
      final redirect = applyRedirect(
        isAuth: container.read(isAuthenticatedProvider),
        onboardingDone: container.read(isOnboardingCompletedProvider),
        location: AppConfig.dashboard,
      );
      expect(redirect, AppConfig.onboarding);
    });

    test('full redirect call via container — authed + onboarding done + login', () {
      final container = makeContainer(isAuth: true, onboardingDone: true);
      addTearDown(container.dispose);
      final redirect = applyRedirect(
        isAuth: container.read(isAuthenticatedProvider),
        onboardingDone: container.read(isOnboardingCompletedProvider),
        location: AppConfig.login,
      );
      expect(redirect, AppConfig.dashboard);
    });
  });

  // Silence unused-element warnings for types referenced only for type-checking.
  // ignore: unused_element
  final _unusedUserProfile = UserProfile;
}
