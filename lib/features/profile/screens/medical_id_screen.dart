import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/providers/medications_provider.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/medical_disclaimer_banner.dart';

class MedicalIdScreen extends ConsumerStatefulWidget {
  const MedicalIdScreen({super.key});

  @override
  ConsumerState<MedicalIdScreen> createState() => _MedicalIdScreenState();
}

class _MedicalIdScreenState extends ConsumerState<MedicalIdScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Medical ID')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          debugPrint('Medical ID load error: $e');
          return Center(child: Text(l10n.somethingWentWrong));
        },
        data: (profile) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              children: [
                // Medical ID Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.urgencyEmergency.withValues(alpha: 0.9),
                        AppColors.urgencyHigh.withValues(alpha: 0.85),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.urgencyEmergency.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Medical ID Header
                        Row(
                          children: [
                            const Icon(Icons.local_hospital, color: Colors.white, size: 28),
                            const SizedBox(width: 12),
                            const Text(
                              'MEDICAL ID',
                              style: TextStyle(
                                fontFamily: 'ClashDisplay',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 2,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'EMERGENCY',
                                style: TextStyle(
                                  fontFamily: 'DMSans',
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Name
                        Text(
                          profile?.fullName ?? 'Unknown',
                          style: const TextStyle(
                            fontFamily: 'ClashDisplay',
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Blood Type - Prominent
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface(isDark),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.bloodtype, color: AppColors.urgencyEmergency, size: 28),
                              const SizedBox(width: 8),
                              Text(
                                profile?.bloodType ?? 'Unknown',
                                style: const TextStyle(
                                  fontFamily: 'ClashDisplay',
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.urgencyEmergency,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Blood Type',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: AppColors.textSecondary(isDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Date of Birth
                        if (profile?.dateOfBirth != null)
                          Text(
                            'DOB: ${profile!.dateOfBirth!.day}/${profile.dateOfBirth!.month}/${profile.dateOfBirth!.year}',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Allergies Section
                _InfoSection(
                  icon: Icons.warning_amber_rounded,
                  iconColor: AppColors.urgencyEmergency,
                  title: 'Allergies',
                  items: profile?.allergies.isEmpty ?? true
                      ? ['None reported']
                      : profile!.allergies,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),

                // Chronic Conditions Section
                _InfoSection(
                  icon: Icons.health_and_safety_outlined,
                  iconColor: isDark ? AppColors.darkWarning : AppColors.lightWarning,
                  title: 'Chronic Conditions',
                  items: profile?.chronicConditions.isEmpty ?? true
                      ? ['None reported']
                      : profile!.chronicConditions,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),

                // Medications Section
                Builder(
                  builder: (context) {
                    final medsAsync = ref.watch(activeMedicationsProvider);
                    final medNames = medsAsync.map((m) => m.displayDosage).toList();
                    return _InfoSection(
                      icon: Icons.medication_outlined,
                      iconColor: isDark ? AppColors.darkInfo : AppColors.lightInfo,
                      title: 'Medications',
                      items: medNames.isEmpty ? ['No active medications'] : medNames,
                      isDark: isDark,
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Emergency Contact Section
                if (profile?.emergencyContacts.isNotEmpty ?? false)
                  _InfoSection(
                    icon: Icons.contact_phone_outlined,
                    iconColor: AppColors.primary(isDark),
                    title: 'Emergency Contact',
                    items: profile!.emergencyContacts.map((c) =>
                      '${c.name}${c.relationship != null ? ' (${c.relationship})' : ''} - ${c.phone}'
                    ).toList(),
                    isDark: isDark,
                  )
                else
                  _InfoSection(
                    icon: Icons.contact_phone_outlined,
                    iconColor: AppColors.primary(isDark),
                    title: 'Emergency Contact',
                    items: const ['No emergency contact set'],
                    isDark: isDark,
                  ),
                const SizedBox(height: 20),

                // QR Code - Navigate to full QR display
                Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => context.push(AppConfig.qrDisplay),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.qr_code_2,
                            size: 120,
                            color: AppColors.primary(isDark),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to view QR Code',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // View QR button (the previous label "Share Medical ID" was
                // misleading — the button only navigates to the QR screen,
                // it doesn't actually share. Now the label matches the action.)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(AppConfig.qrDisplay),
                    icon: const Icon(Icons.qr_code_2),
                    label: Text(
                      AppLocalizations.of(context)!.viewQrCode,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.urgencyEmergency,
                      side: const BorderSide(color: AppColors.urgencyEmergency),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Medical disclaimer — required on every screen displaying
                // clinical data per Cahier des Charges Section 7.
                const MedicalDisclaimerBanner(),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<String> items;
  final bool isDark;

  const _InfoSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.items,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'ClashDisplay',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 48),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: iconColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: isDark ? AppColors.grey300 : AppColors.grey700,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}
