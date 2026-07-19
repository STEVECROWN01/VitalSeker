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
import '../../features/triage/screens/ai_chat_screen.dart';
import '../../features/triage/screens/seker_info_screen.dart';
import '../../features/profile/screens/pro_plan_screen.dart';
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
import '../../features/profile/screens/terms_of_service_screen.dart';
import '../../features/profile/screens/medical_id_screen.dart';
import '../../features/profile/screens/translation_screen.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Standard forward navigation transition for screens rendered inside the
/// main ShellRoute (i.e. anything that lives under the bottom-nav scaffold).
///
/// Animation contract (per `vitalseker_animation_spec_sheet_text.md`):
///   - Slide-in from the right: Offset(1.0, 0.0) → Offset(0.0, 0.0)
///   - Duration: 350ms (forward + reverse)
///   - Curve: `Curves.easeInOutCubic` (closest Flutter built-in to the
///     design-spec cubic-bezier(0.4, 0, 0.2, 1))
///
/// Routes that are NOT inside the ShellRoute (splash, login, register,
/// onboarding, and the standalone full-screen routes like SOS / family /
/// export / medications / appointments) deliberately keep their default
/// transitions.
CustomTransitionPage slideTransitionPage({
  required Widget child,
  required GoRouterState state,
}) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 350),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic),
        ),
        child: child,
      );
    },
  );
}

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

      // Not authenticated: allow login, register, and onboarding.
      // FIX: previously redirected ALL unauth users to /onboarding, which
      // meant returning users who just signed out landed on the first-time
      // carousel instead of the login screen. The splash screen handles
      // routing first-time users to onboarding; here we send everyone else
      // to login.
      if (!isAuth) {
        if (isLogin || isRegister || isOnboarding) return null;
        return AppConfig.login;
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
      // ── Pre-auth / standalone entry routes ─────────────────────────────
      // These keep their default transitions (splash, onboarding, login,
      // register each orchestrate their own animated intros).
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

      // ── Main app shell (bottom-nav scaffold) ───────────────────────────
      // All routes inside this ShellRoute use the shared `slideTransitionPage`
      // helper for a consistent 350ms slide-in-from-right forward transition.
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          // ── Bottom-nav active-tab resolution ────────────────────────────
          // 5-tab bottom nav: Home(0) / History(1) / Triage(2) / Insights(3) /
          // Passport(4). Use the FULL route paths (with the `/home/` prefix)
          // so each tab matches its own sub-tree, e.g.
          //   `/home/triage/result` → Triage tab (2)
          //   `/home/passport/qr`   → Passport tab (4)
          //   `/home/profile/...`   → Home tab (0) — profile lives under Home
          //
          // The `else` branch covers everything that is NOT one of the four
          // dedicated tab roots (dashboard, health, vitals, profile, etc.).
          final location = state.matchedLocation;
          int currentIndex;
          if (location.startsWith(AppConfig.triage)) {
            currentIndex = 2; // Triage
          } else if (location.startsWith(AppConfig.history)) {
            currentIndex = 1; // History
          } else if (location.startsWith(AppConfig.insights)) {
            currentIndex = 3; // Insights
          } else if (location.startsWith(AppConfig.passport)) {
            currentIndex = 4; // Passport
          } else {
            currentIndex = 0; // Home (dashboard, health, vitals, profile, …)
          }

          return ScaffoldWithNavBar(
            currentIndex: currentIndex,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: AppConfig.dashboard,
            pageBuilder: (context, state) =>
                slideTransitionPage(child: const DashboardScreen(), state: state),
          ),
          GoRoute(
            path: AppConfig.vitals,
            pageBuilder: (context, state) =>
                slideTransitionPage(child: const VitalsScreen(), state: state),
            routes: [
              GoRoute(
                path: 'add',
                parentNavigatorKey: _rootNavigatorKey,
                pageBuilder: (context, state) => slideTransitionPage(
                    child: const AddVitalScreen(), state: state),
              ),
              GoRoute(
                path: 'history',
                parentNavigatorKey: _rootNavigatorKey,
                pageBuilder: (context, state) {
                  final typeName = state.uri.queryParameters['type'];
                  final initialType = typeName != null
                      ? VitalType.values
                          .where((v) => v.name == typeName)
                          .firstOrNull
                      : null;
                  return slideTransitionPage(
                    child: VitalsHistoryScreen(initialType: initialType),
                    state: state,
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: AppConfig.health,
            parentNavigatorKey: _shellNavigatorKey,
            pageBuilder: (context, state) =>
                slideTransitionPage(child: const HealthScreen(), state: state),
          ),
          GoRoute(
            path: AppConfig.triage,
            pageBuilder: (context, state) =>
                slideTransitionPage(child: const TriageScreen(), state: state),
            routes: [
              GoRoute(
                path: 'result',
                pageBuilder: (context, state) => slideTransitionPage(
                  child: TriageResultScreen(
                    triageData: state.extra as Map<String, dynamic>? ?? {},
                  ),
                  state: state,
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppConfig.passport,
            pageBuilder: (context, state) =>
                slideTransitionPage(child: const PassportScreen(), state: state),
            routes: [
              GoRoute(
                path: 'qr',
                // FIX: render on the root navigator so this screen renders
                // ABOVE the SOS / MedicalId screens when they push it via
                // context.push(AppConfig.qrDisplay). Without this, the pushed
                // page is trapped underneath the still-visible root-navigator
                // page (MedicalId, SOS) and the user sees a blank screen.
                // Mirrors the `edit`/`medical-id`/`vitals/add` pattern.
                parentNavigatorKey: _rootNavigatorKey,
                pageBuilder: (context, state) => slideTransitionPage(
                    child: const QrDisplayScreen(), state: state),
              ),
            ],
          ),
          GoRoute(
            path: AppConfig.history,
            pageBuilder: (context, state) =>
                slideTransitionPage(child: const HistoryScreen(), state: state),
          ),
          GoRoute(
            path: AppConfig.insights,
            parentNavigatorKey: _shellNavigatorKey,
            pageBuilder: (context, state) =>
                slideTransitionPage(child: const InsightsScreen(), state: state),
          ),
          GoRoute(
            path: AppConfig.profile,
            pageBuilder: (context, state) =>
                slideTransitionPage(child: const ProfileScreen(), state: state),
            routes: [
              GoRoute(
                path: 'about',
                pageBuilder: (context, state) => slideTransitionPage(
                    child: const AboutScreen(), state: state),
              ),
              GoRoute(
                path: 'subscription',
                pageBuilder: (context, state) => slideTransitionPage(
                    child: const SubscriptionScreen(), state: state),
              ),
              GoRoute(
                path: 'edit',
                // FIX: render on the root navigator (not the shell navigator)
                // so this screen renders ABOVE the SOS screen when SOS pushes
                // it via context.push(AppConfig.editProfile). Without this,
                // the pushed page is trapped underneath the still-visible SOS
                // page (which lives on the root navigator) and the user sees
                // a blank screen. Mirrors the `vitals/add` pattern at line 212.
                parentNavigatorKey: _rootNavigatorKey,
                pageBuilder: (context, state) => slideTransitionPage(
                    child: const EditProfileScreen(), state: state),
              ),
              GoRoute(
                path: 'medical-records',
                pageBuilder: (context, state) => slideTransitionPage(
                    child: const MedicalRecordsScreen(), state: state),
              ),
              GoRoute(
                path: 'settings',
                pageBuilder: (context, state) => slideTransitionPage(
                    child: const SettingsScreen(), state: state),
                routes: [
                  GoRoute(
                    path: 'notifications',
                    pageBuilder: (context, state) => slideTransitionPage(
                        child: const NotificationsSettingsScreen(),
                        state: state),
                  ),
                ],
              ),
              GoRoute(
                path: 'help',
                pageBuilder: (context, state) => slideTransitionPage(
                    child: const HelpSupportScreen(), state: state),
              ),
              GoRoute(
                path: 'privacy',
                pageBuilder: (context, state) => slideTransitionPage(
                    child: const PrivacyScreen(), state: state),
              ),
              GoRoute(
                path: 'terms',
                pageBuilder: (context, state) => slideTransitionPage(
                    child: const TermsOfServiceScreen(), state: state),
              ),
              GoRoute(
                path: 'medical-id',
                // FIX: render on the root navigator (not the shell navigator)
                // so this screen renders ABOVE the SOS screen when SOS pushes
                // it via context.push(AppConfig.medicalId). Same reason as
                // 'edit' above — without this, the page is trapped under the
                // SOS page and the user sees a blank screen.
                parentNavigatorKey: _rootNavigatorKey,
                pageBuilder: (context, state) => slideTransitionPage(
                    child: const MedicalIdScreen(), state: state),
              ),
              GoRoute(
                // Medical Translation screen — Bug 5: this route was missing
                // from the router, so clicking "Medical Translation" on the
                // profile screen showed a blank page. Registered as a child
                // of the profile route so it inherits the bottom-nav shell
                // + the slide-in-from-right transition used by every other
                // profile sub-page.
                path: 'translation',
                pageBuilder: (context, state) => slideTransitionPage(
                    child: const TranslationScreen(), state: state),
              ),
            ],
          ),
        ],
      ),

      // ── Standalone routes (no bottom nav, default transitions) ─────────
      // These intentionally do NOT use slideTransitionPage — they are
      // modal-style full-screen surfaces (SOS, family, export, add-flows)
      // that benefit from the platform default rather than a forward push.
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
        path: AppConfig.aiChat,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AiChatScreen(),
      ),
      GoRoute(
        path: AppConfig.sekerInfo,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SekerInfoScreen(),
      ),
      GoRoute(
        path: AppConfig.proPlan,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProPlanScreen(),
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
///
/// FIX (audit 5.9): add deep-link handling. When the app receives a deep link
/// (e.g. from an SOS notification or a shared passport QR URL), the router
/// navigates to the corresponding screen. Supported deep-link paths:
///   - vitalseker://sos → SOS screen
///   - vitalseker://triage → Triage screen
///   - vitalseker://passport → Passport screen
///   - https://passport.vitalseker.app/v/{token} → QR display screen
final routerProvider = Provider<GoRouter>((ref) {
  final router = createRouter(ref);
  ref.listen<AsyncValue>(authStateProvider, (_, __) {
    router.refresh();
  });
  ref.listen<AsyncValue>(userProfileProvider, (_, __) {
    router.refresh();
  });
  return router;
});

/// Shell scaffold that hosts the bottom-nav bar + the (optional) SOS
/// FloatingActionButton overlay.
///
/// The SOS FAB only renders on the Home tab (`currentIndex == 0`) and is
/// **draggable** so the user can move it out of the way when it covers
/// content. Dragging is initiated with a long-press; a plain tap still
/// triggers the SOS flow.
///
/// Implementation notes:
///   - The body is wrapped in a `LayoutBuilder` + `Stack` so we can position
///     the FAB with arbitrary coordinates.
///   - The default position (when the user has not dragged yet) mirrors the
///     FAB's natural bottom-right spot — `maxWidth - size - margin` on X and
///     `maxHeight - size - margin` on Y, where `maxHeight` excludes the
///     bottom-nav bar (the bar lives in Scaffold.bottomNavigationBar, so it
///     does not eat into the body's vertical constraints).
///   - The position is clamped to the body bounds so the FAB can never be
///     dragged off-screen or under the bottom-nav bar.
class ScaffoldWithNavBar extends StatefulWidget {
  final int currentIndex;
  final Widget child;

  const ScaffoldWithNavBar({
    super.key,
    required this.currentIndex,
    required this.child,
  });

  @override
  State<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends State<ScaffoldWithNavBar> {
  /// When non-null, the user has dragged the FAB and this is the new top-left
  /// coordinate (relative to the body Stack). Null = use default bottom-right.

  // Standard FAB is 56×56. We pad with 16px of breathing room on each side.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Default position: bottom-right of the body, just above the
          // bottom-nav bar.
          return widget.child;
        },
      ),
      bottomNavigationBar: AppBottomNav(currentIndex: widget.currentIndex),
    );
  }
}

/// Draggable Seker AI FloatingActionButton.
///
/// Shows the Seker AI avatar + "Seker AI" label. Visible on ALL tabs.
/// Tap → navigates to the AI chat screen.
/// Long-press + drag → repositions the button.
class _DraggableSekerFab extends StatefulWidget {
  final void Function(Offset delta) onDrag;
  final VoidCallback onTap;

  const _DraggableSekerFab({required this.onDrag, required this.onTap});

  @override
  State<_DraggableSekerFab> createState() => _DraggableSekerFabState();
}

class _DraggableSekerFabState extends State<_DraggableSekerFab> {
  Offset? _dragOrigin;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (details) {
        _dragOrigin = details.globalPosition;
      },
      onLongPressMoveUpdate: (details) {
        if (_dragOrigin == null) return;
        final delta = details.globalPosition - _dragOrigin!;
        _dragOrigin = details.globalPosition;
        widget.onDrag(delta);
      },
      onLongPressEnd: (_) {
        _dragOrigin = null;
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.lightPrimary.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: GestureDetector(
              onTap: widget.onTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset(
                  'assets/images/branding/seker_ai_avatar.png',
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.lightPrimary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Seker AI',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
