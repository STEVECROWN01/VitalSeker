import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import '../../shared/theme/app_colors.dart';
import '../../features/splash/screens/splash_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/triage/screens/triage_screen.dart';
import '../../features/triage/screens/triage_result_screen.dart';
import '../../features/passport/screens/passport_screen.dart';
import '../../features/passport/screens/qr_display_screen.dart';
import '../../features/history/screens/history_screen.dart';
import '../../features/insights/screens/insights_screen.dart';
import '../../features/family/screens/family_screen.dart';
import '../../features/export/screens/export_screen.dart';
import '../../features/sos/screens/sos_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/about_screen.dart';
import '../../features/profile/screens/subscription_screen.dart';
import '../../shared/widgets/app_bottom_nav.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(Ref ref) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppConfig.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuth = isAuthenticated;
      final isSplash = state.matchedLocation == AppConfig.splash;
      final isOnboarding = state.matchedLocation == AppConfig.onboarding;
      final isLogin = state.matchedLocation == AppConfig.login;
      final isRegister = state.matchedLocation == AppConfig.register;

      if (isSplash) return null;

      if (!isAuth) {
        if (isLogin || isRegister) return null;
        return AppConfig.login;
      }

      if (isAuth && (isLogin || isRegister)) {
        return AppConfig.dashboard;
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
          if (location.startsWith(AppConfig.triage)) currentIndex = 1;
          else if (location.startsWith(AppConfig.passport)) currentIndex = 2;
          else if (location.startsWith(AppConfig.history)) currentIndex = 3;
          else if (location.startsWith(AppConfig.profile)) currentIndex = 4;
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
    ],
  );
}

final routerProvider = Provider<GoRouter>((ref) => createRouter(ref));

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
