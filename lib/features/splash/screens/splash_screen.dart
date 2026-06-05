import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    context.go(AppConfig.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0A0E17), Color(0xFF0B2E22), Color(0xFF0A0E17)],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF8FAFB), Color(0xFFE0F2F1), Color(0xFFF8FAFB)],
                ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Logo
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.lightPrimary.withValues(alpha: 0.3),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: Colors.white,
                        size: 50,
                      ),
                    ).animate().scale(
                      duration: 600.ms,
                      curve: Curves.elasticOut,
                      begin: const Offset(0.5, 0.5),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      AppConfig.appName,
                      style: TextStyle(
                        fontFamily: 'ClashDisplay',
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.lightOnBackground,
                        letterSpacing: -1,
                      ),
                    ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
                    const SizedBox(height: 8),
                    Text(
                      AppConfig.appTagline,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: isDark ? AppColors.grey400 : AppColors.grey500,
                      ),
                    ).animate().fadeIn(duration: 600.ms, delay: 400.ms),
                  ],
                ),
              ),
              const Spacer(flex: 2),
              // Loading indicator
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 600.ms),
              const SizedBox(height: 32),
              // Keter Marketing credit
              Text(
                'Powered by ${AppConfig.producer}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.grey600 : AppColors.grey400,
                  letterSpacing: 0.5,
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
