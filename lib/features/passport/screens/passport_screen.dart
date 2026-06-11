import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/health_passport_provider.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/vital_score_ring.dart';

class PassportScreen extends ConsumerWidget {
  const PassportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final passportAsync = ref.watch(healthPassportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Passport'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            onPressed: () => context.push('${AppConfig.passport}/qr'),
            tooltip: 'Show QR Code',
          ),
        ],
      ),
      body: passportAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (passport) {
          if (passport == null) {
            return _buildNoPassport(context, isDark);
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Passport Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: isDark
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF0A2E22), Color(0xFF151925)],
                          )
                        : const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF0B7A5B), Color(0xFF0B9E70)],
                          ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.favorite_rounded, color: Colors.white, size: 28),
                              const SizedBox(width: 8),
                              Text(
                                'VitalSeker',
                                style: TextStyle(
                                  fontFamily: 'ClashDisplay',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'HEALTH PASSPORT',
                            style: TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.6),
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      VitalScoreRing(
                        score: passport.vitalScore,
                        size: 80,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white70, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            passport.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().scale(duration: 500.ms, curve: Curves.elasticOut, begin: const Offset(0.95, 0.95)),
                const SizedBox(height: 24),

                // Blood Type
                if (passport.bloodType != null)
                  _InfoCard(
                    icon: Icons.water_drop,
                    iconColor: AppColors.urgencyEmergency,
                    title: 'Blood Type',
                    value: passport.bloodType!,
                  ),

                // Allergies
                if (passport.allergies.isNotEmpty)
                  _InfoCard(
                    icon: Icons.warning_amber,
                    iconColor: AppColors.urgencyMedium,
                    title: 'Allergies',
                    value: passport.allergies.join(', '),
                  ),

                // Medications
                if (passport.medications.isNotEmpty)
                  _InfoCard(
                    icon: Icons.medication,
                    iconColor: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                    title: 'Medications',
                    value: passport.medications.join(', '),
                  ),

                // Chronic Conditions
                if (passport.chronicConditions.isNotEmpty)
                  _InfoCard(
                    icon: Icons.health_and_safety,
                    iconColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                    title: 'Chronic Conditions',
                    value: passport.chronicConditions.join(', '),
                  ),

                // Insurance
                if (passport.insuranceProvider != null)
                  _InfoCard(
                    icon: Icons.shield,
                    iconColor: AppColors.lightInfo,
                    title: 'Insurance',
                    value: '${passport.insuranceProvider}${passport.insurancePolicyNumber != null ? ' - ${passport.insurancePolicyNumber}' : ''}',
                  ),

                // Emergency Contacts
                if (passport.emergencyContacts.isNotEmpty) ...[
                  Text(
                    'Emergency Contacts',
                    style: TextStyle(
                      fontFamily: 'ClashDisplay',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.lightOnBackground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...passport.emergencyContacts.map((contact) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.phone_in_talk, color: AppColors.urgencyEmergency),
                      title: Text(contact.name, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500)),
                      subtitle: Text(contact.phone, style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 13, color: isDark ? AppColors.grey400 : AppColors.grey500)),
                      trailing: contact.relationship != null
                          ? Chip(label: Text(contact.relationship!, style: const TextStyle(fontSize: 11)))
                          : null,
                    ),
                  )),
                ],
                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('${AppConfig.passport}/qr'),
                        icon: const Icon(Icons.qr_code_2),
                        label: const Text('QR Code'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => context.push(AppConfig.exportScreen),
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Export PDF'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoPassport(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.badge_outlined, size: 80, color: isDark ? AppColors.grey600 : AppColors.grey300),
          const SizedBox(height: 16),
          Text(
            'No Health Passport Yet',
            style: TextStyle(
              fontFamily: 'ClashDisplay',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.grey400 : AppColors.grey500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete your first triage to generate\nyour health passport',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: isDark ? AppColors.grey500 : AppColors.grey400,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.push(AppConfig.triage),
            child: const Text('Start Triage'),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: isDark ? AppColors.grey400 : AppColors.grey500,
          ),
        ),
        subtitle: Text(
          value,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : AppColors.lightOnBackground,
          ),
        ),
      ),
    );
  }
}
