import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/medications_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/medical_disclaimer_banner.dart';

class MedicalIdScreen extends ConsumerWidget {
  const MedicalIdScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go(AppConfig.profile);
            }
          },
        ),
        title: Text(l10n.medicalID),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.somethingWentWrong)),
        data: (profile) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Emergency header card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.urgencyEmergency,
                        AppColors.urgencyEmergency.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.urgencyEmergency.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.medical_services, color: Colors.white, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        profile?.fullName ?? l10n.notAvailable,
                        style: const TextStyle(
                          fontFamily: 'ClashDisplay',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Blood Type — clickable to edit
                      GestureDetector(
                        onTap: () => context.push(AppConfig.editProfile),
                        child: Container(
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
                                profile?.bloodType ?? l10n.notAvailable,
                                style: const TextStyle(
                                  fontFamily: 'ClashDisplay',
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.urgencyEmergency,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l10n.bloodTypeLabel,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: AppColors.textSecondary(isDark),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.edit, size: 14, color: AppColors.textSecondary(isDark)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // DOB — clickable to edit
                      if (profile?.dateOfBirth != null)
                        GestureDetector(
                          onTap: () => context.push(AppConfig.editProfile),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${l10n.dateOfBirthLabel}: ${profile!.dateOfBirth!.day}/${profile.dateOfBirth!.month}/${profile.dateOfBirth!.year}',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.edit, size: 12, color: Colors.white.withValues(alpha: 0.6)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Allergies Section — with add button
                _InfoSection(
                  icon: Icons.warning_amber_rounded,
                  iconColor: AppColors.urgencyEmergency,
                  title: l10n.allergiesLabel,
                  items: profile?.allergies.isEmpty ?? true
                      ? ['None reported']
                      : profile!.allergies,
                  isDark: isDark,
                  onAdd: () => context.push(AppConfig.editProfile),
                ),
                const SizedBox(height: 12),

                // Chronic Conditions Section — with add button
                _InfoSection(
                  icon: Icons.health_and_safety_outlined,
                  iconColor: isDark ? AppColors.darkWarning : AppColors.lightWarning,
                  title: l10n.chronicConditionsLabel,
                  items: profile?.chronicConditions.isEmpty ?? true
                      ? ['None reported']
                      : profile!.chronicConditions,
                  isDark: isDark,
                  onAdd: () => context.push(AppConfig.editProfile),
                ),
                const SizedBox(height: 12),

                // Medications Section — with add button
                Builder(
                  builder: (context) {
                    final medsAsync = ref.watch(activeMedicationsProvider);
                    final medNames = medsAsync.map((m) => m.displayDosage).toList();
                    return _InfoSection(
                      icon: Icons.medication_outlined,
                      iconColor: isDark ? AppColors.darkInfo : AppColors.lightInfo,
                      title: l10n.medicationsLabel,
                      items: medNames.isEmpty ? [l10n.noneRecorded] : medNames,
                      isDark: isDark,
                      onAdd: () => context.push(AppConfig.medications),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Emergency Contact Section — clickable to call
                if (profile?.emergencyContacts.isNotEmpty ?? false)
                  ...profile!.emergencyContacts.map((c) => _EmergencyContactCard(
                    name: c.name,
                    phone: c.phone,
                    relationship: c.relationship,
                    isDark: isDark,
                  ))
                else
                  _InfoSection(
                    icon: Icons.contact_phone_outlined,
                    iconColor: AppColors.primary(isDark),
                    title: l10n.emergencyContact,
                    items: const ['—'],
                    isDark: isDark,
                    onAdd: () => context.push(AppConfig.editProfile),
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
                            l10n.tapToViewQrCode,
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
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(AppConfig.qrDisplay),
                    icon: const Icon(Icons.qr_code_2),
                    label: Text(
                      l10n.viewQrCode,
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

/// Info section card with optional "add" button in the top-right corner.
class _InfoSection extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<String> items;
  final bool isDark;
  final VoidCallback? onAdd;

  const _InfoSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.items,
    required this.isDark,
    this.onAdd,
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
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'ClashDisplay',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                ),
                if (onAdd != null)
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, size: 20, color: AppColors.primary(isDark)),
                    onPressed: onAdd,
                    tooltip: AppLocalizations.of(context)!.add,
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
                        color: AppColors.textPrimary(isDark),
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

/// Emergency contact card — tappable to call the contact directly.
class _EmergencyContactCard extends StatelessWidget {
  final String name;
  final String phone;
  final String? relationship;
  final bool isDark;

  const _EmergencyContactCard({
    required this.name,
    required this.phone,
    this.relationship,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final url = Uri.parse('tel:$phone');
          if (await canLaunchUrl(url)) {
            await launchUrl(url);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary(isDark).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.contact_phone_outlined, color: AppColors.primary(isDark), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontFamily: 'ClashDisplay',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                    if (relationship != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        relationship!,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.textSecondary(isDark),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      phone,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: AppColors.primary(isDark),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.phone_in_talk, color: AppColors.primary(isDark), size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
