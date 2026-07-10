import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../shared/theme/app_colors.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _hasNavigated = false;
  late final AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    // Horizontal progress bar: 0→1 over 2.5s (ease-out per animation spec)
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..forward();
    _navigateNext();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _navigateNext() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted || _hasNavigated) return;

    final isAuthenticated = ref.read(isAuthenticatedProvider);

    if (isAuthenticated) {
      final isOnboardingDone = ref.read(isOnboardingCompletedProvider);
      if (isOnboardingDone) {
        _hasNavigated = true;
        context.go(AppConfig.dashboard);
      } else {
        _hasNavigated = true;
        context.go(AppConfig.onboarding);
      }
    } else {
      _hasNavigated = true;
      context.go(AppConfig.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          // Design: radial gradient (light) or solid Deep Forest (dark)
          gradient: isDark
              ? null
              : RadialGradient(
                  center: Alignment.center,
                  radius: 0.8,
                  colors: [
                    AppColors.lightPrimaryContainer, // #E9FEF6 Clean Mint
                    AppColors.lightBackground, // #F9F9FC
                  ],
                ),
          color: isDark ? AppColors.darkBackground : null, // #050F0B
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Logo — displayed clean, edge-to-edge, no extra container.
              // The app_logo.png already contains the teal background + white
              // heart+ECG logo, so we just round the corners and show it.
              Center(
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset(
                        'assets/images/branding/app_logo.png',
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ).animate().scale(
                          duration: 600.ms,
                          curve: Curves.elasticOut,
                          begin: const Offset(0.5, 0.5),
                        ),
                    const SizedBox(height: 24),
                    // Brand name — ClashDisplay ExtraBold w800 per design
                    Text(
                      l10n.appName,
                      style: TextStyle(
                        fontFamily: 'ClashDisplay',
                        fontSize: 32,
                        fontWeight: FontWeight.w800, // ExtraBold per design
                        color: AppColors.textPrimary(isDark),
                        letterSpacing: -0.02, // -0.02em per tokens
                      ),
                    ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
                    const SizedBox(height: 8),
                    // Tagline — per design tokens
                    Text(
                      l10n.tagline, // "Your AI Health Companion"
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary(isDark),
                      ),
                    ).animate().fadeIn(duration: 600.ms, delay: 400.ms),
                  ],
                ),
              ),
              const Spacer(flex: 2),
              // Horizontal progress bar — 160×3px per design (replaces CircularProgressIndicator)
              AnimatedBuilder(
                animation: _progressController,
                builder: (context, _) {
                  return Container(
                    width: 160,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.primary(isDark).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: FractionallySizedBox(
                      widthFactor: _progressController.value,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary(isDark),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  );
                },
              ).animate().fadeIn(duration: 400.ms, delay: 600.ms),
              const SizedBox(height: 32),
              // Keter Marketing credit — design spec wording + DM Sans label-bold uppercase
              Text(
                l10n.poweredByProducer(AppConfig.producer),
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 10,
                  fontWeight: FontWeight.w700, // Bold per design
                  color: AppColors.textTertiary(isDark),
                  letterSpacing: 0.05, // 0.05em per tokens
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 800.ms),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
