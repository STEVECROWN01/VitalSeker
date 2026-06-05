import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/services/database_service.dart';
import '../../../shared/theme/app_colors.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isNavigating = false;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      icon: Icons.favorite_rounded,
      title: 'Your Health Passport',
      description: 'Carry a complete, encrypted health profile wherever you go. Share vital information instantly with any healthcare provider through a secure QR code.',
      gradient: [Color(0xFF0B7A5B), Color(0xFF0B9E70)],
    ),
    OnboardingPage(
      icon: Icons.psychology_rounded,
      title: 'AI Symptom Triage',
      description: 'Describe your symptoms and get instant AI-powered triage recommendations. Know when to self-care, schedule an appointment, or seek emergency help.',
      gradient: [Color(0xFF6C63FF), Color(0xFF8B83FF)],
    ),
    OnboardingPage(
      icon: Icons.family_restroom_rounded,
      title: 'Family Health Hub',
      description: 'Manage health profiles for your entire family. Track symptoms, store medical information, and ensure everyone gets the care they need.',
      gradient: [Color(0xFFFF6B6B), Color(0xFFFFB347)],
    ),
    OnboardingPage(
      icon: Icons.health_and_safety_rounded,
      title: 'Emergency SOS',
      description: 'One-tap emergency alerts with automatic GPS location sharing. Instantly notify your emergency contacts via SMS when every second counts.',
      gradient: [Color(0xFFE53935), Color(0xFFFF5722)],
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
      // Mark onboarding as completed in the database for logged-in users
      final user = ref.read(currentUserProvider);
      if (user != null) {
        try {
          final db = DatabaseService();
          await db.completeOnboarding(user.id);
          // Refresh the profile provider to reflect onboarding status
          ref.invalidate(userProfileProvider);
        } catch (e) {
          // Don't block navigation if DB update fails
          debugPrint('Failed to mark onboarding complete: $e');
        }
      }

      if (!mounted) return;

      // Navigate based on auth state
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

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finishOnboarding,
                child: Text(
                  'Skip',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    color: isDark ? AppColors.grey400 : AppColors.grey500,
                  ),
                ),
              ),
            ),
            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
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
                        Text(
                          page.title,
                          style: TextStyle(
                            fontFamily: 'ClashDisplay',
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.lightOnBackground,
                          ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                        const SizedBox(height: 16),
                        Text(
                          page.description,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: isDark ? AppColors.grey400 : AppColors.grey500,
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Page indicators
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 32 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? AppColors.lightPrimary
                          : (isDark ? AppColors.grey700 : AppColors.grey200),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            // Action button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isNavigating ? null : () {
                    if (_currentPage == _pages.length - 1) {
                      _finishOnboarding();
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.lightPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isNavigating
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
            // Keter Marketing credit
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Powered by ${AppConfig.producer}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: isDark ? AppColors.grey600 : AppColors.grey400,
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
  final String title;
  final String description;
  final List<Color> gradient;

  OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
  });
}
