import 'package:flutter_test/flutter_test.dart';
import 'package:vitalseker/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('exposes app metadata', () {
      expect(AppConfig.appName, 'VitalSeker');
      expect(AppConfig.appTagline, 'Your AI Health Companion');
      expect(AppConfig.producer, 'Keter Marketing');
      expect(AppConfig.version, '1.0.0');
    });

    test('exposes pricing constants', () {
      expect(AppConfig.proPriceMonthly, 6.99);
      expect(AppConfig.enterprisePriceMonthly, 199.0);
    });

    test('route paths are unique and well-formed', () {
      final routes = <String>{
        AppConfig.splash,
        AppConfig.onboarding,
        AppConfig.login,
        AppConfig.register,
        AppConfig.home,
        AppConfig.dashboard,
        AppConfig.health,
        AppConfig.triage,
        AppConfig.triageResult,
        AppConfig.passport,
        AppConfig.qrDisplay,
        AppConfig.history,
        AppConfig.insights,
        AppConfig.family,
        AppConfig.exportScreen,
        AppConfig.sos,
        AppConfig.profile,
        AppConfig.about,
        AppConfig.subscription,
        AppConfig.editProfile,
        AppConfig.medicalRecords,
        AppConfig.settings,
        AppConfig.notificationsSettings,
        AppConfig.helpSupport,
        AppConfig.privacyPolicy,
        AppConfig.medicalId,
        AppConfig.medications,
        AppConfig.addMedication,
        AppConfig.appointments,
        AppConfig.addAppointment,
        AppConfig.vitals,
        AppConfig.addVital,
        AppConfig.vitalsHistory,
      };
      // All route constants are distinct — no accidental duplicate path typos.
      expect(routes.length, 35);
      // All start with /.
      for (final r in routes) {
        expect(r.startsWith('/'), isTrue);
      }
    });

    test('auth routes are top-level (not under /home)', () {
      expect(AppConfig.login, '/login');
      expect(AppConfig.register, '/register');
      expect(AppConfig.onboarding, '/onboarding');
      expect(AppConfig.splash, '/');
    });

    test('protected routes are under /home prefix', () {
      // The router's redirect logic treats anything not in
      // {splash, login, register, onboarding} as protected.
      // So all post-login screens should live under /home/*.
      expect(AppConfig.dashboard.startsWith('/home'), isTrue);
      expect(AppConfig.vitals.startsWith('/home'), isTrue);
      expect(AppConfig.profile.startsWith('/home'), isTrue);
      expect(AppConfig.sos.startsWith('/home'), isTrue);
    });
  });
}
