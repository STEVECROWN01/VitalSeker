import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../models/vital.dart';
import '../providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';
import '../../shared/theme/app_colors.dart';
import '../../features/splash/screens/splash_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/health/screens/health_screen.dart';
import '../../features/triage/screens/triage_screen.dart';
import '../../features/triage/screens/triage_result_screen.dart';
import '../../features/passport/screens/passport_screen.dart';
import '../../features/passport/screens/qr_display_screen.dart';
import '../../features/history/screens/history_screen.dart';
import '../../features/insights/screens/insights_screen.dart';
import '../../features/family/screens/family_screen.dart';
import '../../features/export/screens/export_screen.dart';
import '../../features/sos/screens/sos_screen.dart';
import '../../features/vitals/screens/vitals_screen.dart';
import '../../features/vitals/screens/add_vital_screen.dart';
import '../../features/vitals/screens/vitals_history_screen.dart';
import '../../features/medications/screens/medications_screen.dart';
import '../../features/medications/screens/add_medication_screen.dart';
import '../../features/appointments/screens/appointments_screen.dart';
import '../../features/appointments/screens/add_appointment_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/about_screen.dart';
import '../../features/profile/screens/subscription_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/profile/screens/medical_records_screen.dart';
import '../../features/profile/screens/settings_screen.dart';
import '../../features/profile/screens/notifications_settings_screen.dart';
import '../../features/profile/screens/help_support_screen.dart';
import '../../features/profile/screens/privacy_screen.dart';
import '../../features/profile/screens/medical_id_screen.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(Ref ref) {
  // Read auth + onboarding state *inside* the redirect callback so the
  // latest values are always used. The previous implementation captured
  // `isAuthenticated` once at construction time, which meant sign-in/out
  // transitions did not refresh routes until the next manual navigation.
  //
  // We still rely on `routerProvider` rebuilding when `authStateProvider`
  // emits a new value (Riverpod will rebuild on dependency change), but
  // reading inside `redirect` makes the gate robust against stale closures.

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppConfig.splash,
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) {
      final isAuth = ref.read(isAuthenticatedProvider);
      final onboardingDone = ref.read(isOnboardingCompletedProvider);
      final isSplash = state.matchedLocation == AppConfig.splash;
      final isOnboarding = state.matchedLocation == AppConfig.onboarding;
      final isLogin = state.matchedLocation == AppConfig.login;
      final isRegister = state.matchedLocation == AppConfig.register;

      // Allow splash to load (it handles its own navigation)
      if (isSplash) return null;

      // Not authenticated: only allow login, register, onboarding
      if (!isAuth) {
        if (isLogin || isRegister || isOnboarding) return null;
        return AppConfig.onboarding;
      }

      // Authenticated: redirect away from auth screens
      if (isLogin || isRegister) {
        // If onboarding not done, send there first; otherwise dashboard.
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
    },
    routes: [
      GoRoute(
        path: AppConfig.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppConfig.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppConfig.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppConfig.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          int currentIndex = 0;
          final location = state.matchedLocation;
          if (location.startsWith(AppConfig.vitals)) currentIndex = 1;
          else if (location.startsWith(AppConfig.triage)) currentIndex = 2;
          else if (location.startsWith(AppConfig.profile)) currentIndex = 3;
          else currentIndex = 0;

          return ScaffoldWithNavBar(
            currentIndex: currentIndex,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: AppConfig.dashboard,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: AppConfig.vitals,
            builder: (context, state) => const VitalsScreen(),
            routes: [
              GoRoute(
                path: 'add',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const AddVitalScreen(),
              ),
              GoRoute(
                path: 'history',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) {
                  final typeName = state.uri.queryParameters['type'];
                  final initialType = typeName != null
                      ? VitalType.values.where((v) => v.name == typeName).firstOrNull
                      : null;
                  return VitalsHistoryScreen(initialType: initialType);
                },
              ),
            ],
          ),
          GoRoute(
            path: AppConfig.health,
            parentNavigatorKey: _shellNavigatorKey,
            builder: (context, state) => const HealthScreen(),
          ),
          GoRoute(
            path: AppConfig.triage,
            builder: (context, state) => const TriageScreen(),
            routes: [
              GoRoute(
                path: 'result',
                builder: (context, state) => TriageResultScreen(
                  triageData: state.extra as Map<String, dynamic>? ?? {},
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppConfig.passport,
            builder: (context, state) => const PassportScreen(),
            routes: [
              GoRoute(
                path: 'qr',
                builder: (context, state) => const QrDisplayScreen(),
              ),
            ],
          ),
          GoRoute(
            path: AppConfig.history,
            builder: (context, state) => const HistoryScreen(),
          ),
          GoRoute(
            path: AppConfig.profile,
            builder: (context, state) => const ProfileScreen(),
            routes: [
              GoRoute(
                path: 'about',
                builder: (context, state) => const AboutScreen(),
              ),
              GoRoute(
                path: 'subscription',
                builder: (context, state) => const SubscriptionScreen(),
              ),
              GoRoute(
                path: 'edit',
                builder: (context, state) => const EditProfileScreen(),
              ),
              GoRoute(
                path: 'medical-records',
                builder: (context, state) => const MedicalRecordsScreen(),
              ),
              GoRoute(
                path: 'settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'notifications',
                    builder: (context, state) => const NotificationsSettingsScreen(),
                  ),
                ],
              ),
              GoRoute(
                path: 'help',
                builder: (context, state) => const HelpSupportScreen(),
              ),
              GoRoute(
                path: 'privacy',
                builder: (context, state) => const PrivacyScreen(),
              ),
              GoRoute(
                path: 'medical-id',
                builder: (context, state) => const MedicalIdScreen(),
              ),
            ],
          ),
        ],
      ),
      // Standalone routes (no bottom nav)
      GoRoute(
        path: AppConfig.insights,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const InsightsScreen(),
      ),
      GoRoute(
        path: AppConfig.family,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const FamilyScreen(),
      ),
      GoRoute(
        path: AppConfig.exportScreen,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ExportScreen(),
      ),
      GoRoute(
        path: AppConfig.sos,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SosScreen(),
      ),
      GoRoute(
        path: AppConfig.medications,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MedicationsScreen(),
      ),
      GoRoute(
        path: AppConfig.addMedication,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AddMedicationScreen(),
      ),
      GoRoute(
        path: AppConfig.appointments,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AppointmentsScreen(),
      ),
      GoRoute(
        path: AppConfig.addAppointment,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AddAppointmentScreen(),
      ),
    ],
  );
}

/// Refresh the router whenever the auth state changes. This ensures that
/// sign-in / sign-out transitions trigger a re-evaluation of the `redirect`
/// callback (which reads the latest auth + onboarding state).
final routerProvider = Provider<GoRouter>((ref) {
  final router = createRouter(ref);
  ref.listen<AsyncValue>(authStateProvider, (_, __) {
    router.refresh();
  });
  // Also refresh when the user profile changes (e.g. onboarding flag flips).
  ref.listen<AsyncValue>(userProfileProvider, (_, __) {
    router.refresh();
  });
  return router;
});

class ScaffoldWithNavBar extends StatelessWidget {
  final int currentIndex;
  final Widget child;

  const ScaffoldWithNavBar({
    super.key,
    required this.currentIndex,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: AppBottomNav(currentIndex: currentIndex),
      floatingActionButton: currentIndex == 0
          ? FloatingActionButton(
              heroTag: 'sos_fab',
              onPressed: () => context.push(AppConfig.sos),
              backgroundColor: AppColors.urgencyEmergency,
              child: const Icon(Icons.emergency, color: Colors.white),
            )
          : null,
    );
  }
}
