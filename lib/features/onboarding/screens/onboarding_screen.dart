import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/services/database_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_snack_bar.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isNavigating = false;

  // Design-correct gradients per Stitch mockups.
  // Slide 1: "Know your body." — symptom checking
  // Slide 2: "Your health, always with you." — health passport
  // Slide 3: "Works everywhere. Even offline." — 40+ languages, offline support
  // Titles/descriptions are localized, so the pages list is built inside
  // [build] where [AppLocalizations] is available.
  List<OnboardingPage> _buildPages(AppLocalizations l10n) => [
    OnboardingPage(
      icon: Icons.favorite_rounded,
      imageAsset: 'assets/images/branding/app_logo.png',
      title: l10n.onboardingTitle1,
      description: l10n.onboardingDescription1,
      gradient: [const Color(0xFF054D39), const Color(0xFF0B7A5B)], // ForestDark → VitalGreen
    ),
    OnboardingPage(
      icon: Icons.badge_rounded,
      title: l10n.onboardingTitle2,
      description: l10n.onboardingDescription2,
      gradient: [const Color(0xFF0B7A5B), const Color(0xFF0B9E70)], // VitalGreen → Electric Mint
    ),
    OnboardingPage(
      icon: Icons.language_rounded,
      title: l10n.onboardingTitle3,
      description: l10n.onboardingDescription3,
      gradient: [const Color(0xFF0B9E70), const Color(0xFF1DB886)], // Electric Mint → lighter mint
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);

    try {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        try {
          final db = DatabaseService();
          await db.completeOnboarding(user.id);
          ref.invalidate(userProfileProvider);
          // Wait for the provider to refresh so the router redirect sees the
          // updated onboarding_completed=true. Without this, the router may
          // bounce the user back to onboarding (redirect loop).
          await ref.read(userProfileProvider.future);
        } catch (e) {
          if (!mounted) return;
          // Surface the failure — don't navigate to dashboard if the DB write
          // failed, or the router will bounce the user back to onboarding
          // (isOnboardingCompletedProvider still returns false).
          final l10n = AppLocalizations.of(context)!;
          AppSnackBar.error(context, l10n.failedToCompleteOnboarding);
          return;
        }
      }

      if (!mounted) return;

      final isAuthenticated = ref.read(isAuthenticatedProvider);
      if (isAuthenticated) {
        context.go(AppConfig.dashboard);
      } else {
        context.go(AppConfig.login);
      }
    } finally {
      if (mounted) setState(() => _isNavigating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final pages = _buildPages(l10n);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: TextButton(
                  onPressed: _finishOnboarding,
                  child: Text(
                    l10n.skip,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                ),
              ),
            ),
            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: pages.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final page = pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24), // 24dp page margin per tokens
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Hero icon. For pages with an imageAsset (e.g. the app
                        // icon on the first page), show it clean — no gradient
                        // container. For other pages, use the gradient container
                        // with a Material icon inside.
                        if (page.imageAsset != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(40),
                            child: Image.asset(
                              page.imageAsset!,
                              width: 140,
                              height: 140,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            ),
                          ).animate().scale(
                                duration: 500.ms,
                                curve: Curves.elasticOut,
                              )
                        else
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: page.gradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(40),
                              boxShadow: [
                                BoxShadow(
                                  color: page.gradient[0].withValues(alpha: 0.3),
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                ),
                              ],
                            ),
                            child: Icon(page.icon, color: Colors.white, size: 64),
                          ).animate().scale(
                                duration: 500.ms,
                                curve: Curves.elasticOut,
                              ),
                        const SizedBox(height: 40),
                        // Title — ClashDisplay ExtraBold w800 per design tokens
                        Text(
                          page.title,
                          style: TextStyle(
                            fontFamily: 'ClashDisplay',
                            fontSize: 32, // hero-lg-mobile per DESIGN.md
                            fontWeight: FontWeight.w800, // ExtraBold per tokens
                            color: AppColors.textPrimary(isDark),
                            height: 1.15,
                            letterSpacing: -0.02, // -0.02em per tokens
                          ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                        const SizedBox(height: 16),
                        // Description — Inter body 16px, line-height 1.6 per design
                        Text(
                          page.description,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary(isDark),
                            height: 1.6, // 1.6 per DESIGN.md
                          ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Page indicators — per design: active w-6 h-2, inactive w-2 h-2
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(pages.length, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8, // w-6 (24px) per design
                    height: 8, // h-2 (8px) per design
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? AppColors.primary(isDark)
                          : AppColors.outlineVariant(isDark),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            // Action button — pill shape (rounded-full) in dark mode per design
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: 52, // 52px min touch target per DESIGN.md
                child: ElevatedButton(
                  onPressed: _isNavigating ? null : () {
                    if (_currentPage == pages.length - 1) {
                      _finishOnboarding();
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 350), // 350ms per animation spec
                        curve: Curves.easeInOutCubic, // cubic-bezier(0.4, 0, 0.2, 1) per spec
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary(isDark),
                    shape: RoundedRectangleBorder(
                      // Pill shape in dark mode per design; rounded in light
                      borderRadius: BorderRadius.circular(isDark ? 999 : 12),
                    ),
                  ),
                  child: _isNavigating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _currentPage == pages.length - 1 ? l10n.enterVitalSeker : l10n.next,
                          style: AppTextStyles.button.copyWith(color: Colors.white),
                        ),
                ),
              ),
            ),
            // Keter Marketing credit — design spec wording + DM Sans label-bold
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                l10n.poweredByProducer(AppConfig.producer),
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textTertiary(isDark),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingPage {
  final IconData icon;
  final String? imageAsset; // If set, renders an Image instead of the IconData
  final String title;
  final String description;
  final List<Color> gradient;

  OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
    this.imageAsset,
  });
}
