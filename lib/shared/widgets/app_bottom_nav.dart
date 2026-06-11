import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/app_config.dart';
import '../../shared/theme/app_colors.dart';

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
            context.go(AppConfig.vitals);
            break;
          case 2:
            context.go(AppConfig.triage);
            break;
          case 3:
            context.go(AppConfig.profile);
            break;
        }
      },
      backgroundColor: AppColors.surface(isDark),
      indicatorColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
      destinations: [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.monitor_heart_outlined),
          selectedIcon: Icon(Icons.monitor_heart),
          label: 'Vitals',
        ),
        NavigationDestination(
          icon: Icon(Icons.healing_outlined),
          selectedIcon: Icon(Icons.healing),
          label: 'Triage',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
