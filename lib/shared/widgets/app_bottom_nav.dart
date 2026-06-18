import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/app_config.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_text_styles.dart';

/// Bottom navigation bar — 5 tabs per the Google Stitch design:
/// Home / History / Triage / Insights / Passport.
///
/// Design spec (vitalseker_2/DESIGN.md):
///   "A fixed 5-tab bar featuring Home, History, Triage, Insights, and Passport.
///    Icons should be 24x24px with DM Sans Bold labels at 11px."
class AppBottomNav extends StatelessWidget {
  final int currentIndex;

  const AppBottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        switch (index) {
          case 0:
            context.go(AppConfig.dashboard);
            break;
          case 1:
            context.go(AppConfig.history);
            break;
          case 2:
            context.go(AppConfig.triage);
            break;
          case 3:
            context.go(AppConfig.insights);
            break;
          case 4:
            context.go(AppConfig.passport);
            break;
        }
      },
      backgroundColor: AppColors.surface(isDark),
      indicatorColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final isSelected = states.contains(WidgetState.selected);
        return AppTextStyles.labelSmall.copyWith(
          color: isSelected
              ? AppColors.primary(isDark)
              : AppColors.textSecondary(isDark),
        );
      }),
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: const Icon(Icons.history_outlined),
          selectedIcon: const Icon(Icons.history),
          label: 'History',
        ),
        NavigationDestination(
          icon: const Icon(Icons.healing_outlined),
          selectedIcon: const Icon(Icons.healing),
          label: 'Triage',
        ),
        NavigationDestination(
          icon: const Icon(Icons.insights_outlined),
          selectedIcon: const Icon(Icons.insights),
          label: 'Insights',
        ),
        NavigationDestination(
          icon: const Icon(Icons.badge_outlined),
          selectedIcon: const Icon(Icons.badge),
          label: 'Passport',
        ),
      ],
    );
  }
}
