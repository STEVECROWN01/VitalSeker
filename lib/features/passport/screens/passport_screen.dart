import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/medication.dart';
import '../../../core/providers/health_passport_provider.dart';
import '../../../core/providers/medications_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/medical_disclaimer_banner.dart';
import '../../../shared/widgets/vital_score_ring.dart';

class PassportScreen extends ConsumerWidget {
  const PassportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final passportAsync = ref.watch(healthPassportProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final medicationsAsync = ref.watch(medicationsProvider);
    final isPro = ref.watch(isProUserProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go(AppConfig.dashboard);
            }
          },
        ),
        title: Text(
          l10n.healthPassport,
          style: AppTextStyles.heading3.copyWith(color: AppColors.primary(isDark)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            onPressed: () async {
              // FIX: use the ASYNC Pro provider so paying users aren't
              // briefly blocked during the loading window on cold start.
              // The sync provider returns false while the async provider
              // is still resolving.
              final isPro = await ref.read(isProUserAsyncProvider.future);
              if (!context.mounted) return;
              if (!isPro) {
                context.push(AppConfig.proPlan);
              } else {
                context.push('${AppConfig.passport}/qr');
              }
            },
            tooltip: l10n.showQrCode,
          ),
        ],
      ),
      body: passportAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary(isDark))),
        ),
        data: (passport) {
          if (passport == null) {
            return _buildNoPassport(context, isDark);
          }
          final profile = profileAsync.valueOrNull;
          final name = profile?.fullName ?? 'User';
          final dob = profile?.dateOfBirth;
          final heightCm = profile?.heightCm;
          final weightKg = profile?.weightKg;
          // Passport.medications is a List<String> of names — try to enrich
          // with dosage from the medications provider when available.
          final medDetailMap = <String, Medication>{};
          final meds = medicationsAsync.valueOrNull ?? const <Medication>[];
          for (final m in meds) {
            medDetailMap[m.name.toLowerCase()] = m;
          }

          return SingleChildScrollView(
            // ClampingScrollPhysics prevents the over-scroll "bounce" that
            // made the screen feel like it scrolled endlessly even when the
            // passport content was shorter than the viewport. With clamping,
            // the scroll view only scrolls when content actually overflows.
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Hero card ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradientFor(isDark),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary(isDark).withValues(alpha: 0.3),
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
                          // Brand name only — the semi-transparent white
                          // rectangle that wrapped the app logo has been
                          // removed (it was appearing as a "transparent
                          // rectangular frame" in the top-left corner because
                          // the logo PNG has transparent padding around the
                          // mark, letting the tinted background show through).
                          Text(
                            'VitalSeker',
                            style: AppTextStyles.subheading1.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            l10n.healthPassport.toUpperCase(),
                            style: AppTextStyles.labelSmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.65),
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      VitalScoreRing(
                        score: passport.vitalScore,
                        size: 80,
                      ),
                      const SizedBox(height: 18),

                      // ── Name + edit pencil ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            name,
                            style: AppTextStyles.heading3.copyWith(
                              color: Colors.white,
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => context.push(AppConfig.editProfile),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.edit,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── Status pills row ──
                      Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (passport.bloodType != null)
                              _StatusPill(
                                icon: Icons.water_drop,
                                label: passport.bloodType!,
                                bg: Colors.white.withValues(alpha: 0.16),
                                fg: Colors.white,
                                iconColor: Colors.white.withValues(alpha: 0.9),
                              ),
                            if (passport.allergies.isNotEmpty)
                              _StatusPill(
                                icon: Icons.warning_amber_rounded,
                                label:
                                    l10n.allergiesCount(passport.allergies.length),
                                bg: const Color(0xFFFFDAD6).withValues(alpha: isDark ? 0.35 : 0.85),
                                fg: isDark ? const Color(0xFFFFB4AB) : const Color(0xFF93000A),
                                iconColor: isDark ? const Color(0xFFFFB4AB) : AppColors.lightError,
                              ),
                            if (passport.medications.isNotEmpty)
                              _StatusPill(
                                icon: Icons.medication_rounded,
                                label:
                                    l10n.medicationsCount(passport.medications.length),
                                bg: Colors.white.withValues(alpha: 0.16),
                                fg: Colors.white,
                                iconColor: Colors.white.withValues(alpha: 0.9),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            passport.isActive ? Icons.check_circle : Icons.pause_circle,
                            color: Colors.white.withValues(alpha: 0.85),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            passport.isActive ? l10n.active : l10n.inactive,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().scale(
                      duration: 500.ms,
                      curve: Curves.elasticOut,
                      begin: const Offset(0.95, 0.95),
                    ),
                const SizedBox(height: 20),

                // ── DOB / Height & Weight grid ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _DateCard(
                        isDark: isDark,
                        dateOfBirth: dob,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BiometricsCard(
                        isDark: isDark,
                        heightCm: heightCm,
                        weightKg: weightKg,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Allergies (chips) ──
                if (passport.allergies.isNotEmpty) ...[
                  _SectionCard(
                    isDark: isDark,
                    heading: l10n.knownAllergies,
                    headingIcon: Icons.coronavirus_rounded,
                    headingColor: AppColors.error(isDark),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: passport.allergies
                          .map((a) => _AllergyChip(label: a, isDark: isDark))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  // FIX (audit M-5): show an empty-state card so the user
                  // knows the field exists and can add their allergies.
                  _EmptyStateCard(
                    isDark: isDark,
                    icon: Icons.coronavirus_rounded,
                    iconColor: AppColors.error(isDark),
                    title: l10n.knownAllergies,
                    message: 'No allergies recorded. Add yours in Edit Profile '
                        'so emergency responders are aware.',
                    ctaLabel: l10n.editProfile,
                    onCtaTap: () => context.push(AppConfig.editProfile),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Medications ──
                if (passport.medications.isNotEmpty) ...[
                  _SectionCard(
                    isDark: isDark,
                    heading: l10n.currentMedications,
                    headingIcon: Icons.medication_rounded,
                    headingColor: AppColors.primary(isDark),
                    action: GestureDetector(
                      onTap: () => context.push(AppConfig.medications),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.subtleBackground(isDark),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.add, size: 18, color: AppColors.primary(isDark)),
                      ),
                    ),
                    child: Column(
                      children: passport.medications.map((name) {
                        final detail = medDetailMap[name.toLowerCase()];
                        final dosage = detail != null
                            ? '${detail.displayDosage} • ${detail.displayFrequency}'
                            : null;
                        return _MedicationRow(
                          isDark: isDark,
                          name: name,
                          dosage: dosage,
                          isActive: detail?.status == MedicationStatus.active || detail == null,
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  // FIX (audit M-5): empty-state card for medications.
                  _EmptyStateCard(
                    isDark: isDark,
                    icon: Icons.medication_rounded,
                    iconColor: AppColors.primary(isDark),
                    title: l10n.currentMedications,
                    message: 'No medications recorded. Add your current '
                        'prescriptions so they appear on your passport.',
                    ctaLabel: l10n.addMedication,
                    onCtaTap: () => context.push(AppConfig.addMedication),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Chronic Conditions ──
                if (passport.chronicConditions.isNotEmpty)
                  _InfoCard(
                    icon: Icons.health_and_safety,
                    iconColor: AppColors.primary(isDark),
                    title: l10n.chronicConditions,
                    value: passport.chronicConditions.join(', '),
                  )
                else ...[
                  // FIX (audit M-5): empty-state card for chronic conditions.
                  _EmptyStateCard(
                    isDark: isDark,
                    icon: Icons.health_and_safety,
                    iconColor: AppColors.primary(isDark),
                    title: l10n.chronicConditions,
                    message: 'No chronic conditions recorded. Add any ongoing '
                        'conditions (diabetes, hypertension, etc.) in Edit Profile.',
                    ctaLabel: l10n.editProfile,
                    onCtaTap: () => context.push(AppConfig.editProfile),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Insurance (legacy _InfoCard) ──
                if (passport.insuranceProvider != null)
                  _InfoCard(
                    icon: Icons.shield,
                    iconColor: AppColors.info(isDark),
                    title: l10n.insurance,
                    value:
                        '${passport.insuranceProvider}${passport.insurancePolicyNumber != null ? ' - ${passport.insurancePolicyNumber}' : ''}',
                  ),

                // ── Emergency Contacts ──
                if (passport.emergencyContacts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.emergencyContacts,
                    style: AppTextStyles.subheading1
                        .copyWith(color: AppColors.textPrimary(isDark)),
                  ),
                  const SizedBox(height: 8),
                  ...passport.emergencyContacts.map(
                    (contact) => Card(
                      color: AppColors.cardBackground(isDark),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isDark
                              ? AppColors.darkOutlineVariant
                              : Colors.black.withValues(alpha: 0.05),
                        ),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.urgencyEmergency.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.phone_in_talk,
                              color: AppColors.urgencyEmergency, size: 20),
                        ),
                        title: Text(contact.name,
                            style: AppTextStyles.subheading2
                                .copyWith(color: AppColors.textPrimary(isDark))),
                        subtitle: Text(
                          contact.phone,
                          style: AppTextStyles.monoSmall
                              .copyWith(color: AppColors.textSecondary(isDark)),
                        ),
                        trailing: contact.relationship != null
                            ? Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.secondaryContainer(isDark),
                                  borderRadius: BorderRadius.circular(9999),
                                ),
                                child: Text(
                                  contact.relationship!,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: isDark
                                        ? AppColors.darkOnSurface
                                        : const Color(0xFF326F59),
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // ── Action buttons ──
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
            onPressed: () async {
              // FIX: use the ASYNC Pro provider (see AppBar QR button above).
              final isPro = await ref.read(isProUserAsyncProvider.future);
              if (!context.mounted) return;
              if (!isPro) {
                context.push(AppConfig.proPlan);
              } else {
                context.push('${AppConfig.passport}/qr');
              }
            },
                        icon: const Icon(Icons.qr_code_2),
                        label: Text(l10n.qrCode),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: AppColors.border(isDark)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => context.push(AppConfig.exportScreen),
                        icon: const Icon(Icons.picture_as_pdf),
                        label: Text(l10n.exportPdf),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppColors.primary(isDark),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const MedicalDisclaimerBanner(),

                // ── Footer ──
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    l10n.poweredBy(AppConfig.producer),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textTertiary(isDark).withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoPassport(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.badge_outlined, size: 80, color: AppColors.textTertiary(isDark)),
          const SizedBox(height: 16),
          Text(
            l10n.noHealthPassportYet,
            style: AppTextStyles.heading4
                .copyWith(color: AppColors.textSecondary(isDark)),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.completeFirstTriage,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textHint(isDark)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go(AppConfig.triage),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary(isDark),
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.startTriage),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  final Color iconColor;

  const _StatusPill({
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: fg.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  final bool isDark;
  final DateTime? dateOfBirth;

  const _DateCard({required this.isDark, required this.dateOfBirth});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dobStr = dateOfBirth != null
        ? '${dateOfBirth!.year}-${dateOfBirth!.month.toString().padLeft(2, '0')}-${dateOfBirth!.day.toString().padLeft(2, '0')}'
        : '—';
    final age = dateOfBirth != null
        ? l10n.yearsOld(DateTime.now().difference(dateOfBirth!).inDays ~/ 365)
        : l10n.notSet;

    return _GridCard(
      isDark: isDark,
      icon: Icons.calendar_today_outlined,
      label: l10n.dateOfBirth,
      children: [
        Text(
          dobStr,
          style: AppTextStyles.monoRegular.copyWith(
            color: AppColors.textPrimary(isDark),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          age,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary(isDark),
          ),
        ),
      ],
    );
  }
}

class _BiometricsCard extends StatelessWidget {
  final bool isDark;
  final double? heightCm;
  final double? weightKg;

  const _BiometricsCard({
    required this.isDark,
    required this.heightCm,
    required this.weightKg,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _GridCard(
      isDark: isDark,
      icon: Icons.height,
      label: l10n.heightAndWeight,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              heightCm != null ? heightCm!.toStringAsFixed(0) : '—',
              style: AppTextStyles.heading3.copyWith(
                color: AppColors.textPrimary(isDark),
                fontSize: 22,
                height: 1,
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                'cm',
                style: AppTextStyles.monoSmall
                    .copyWith(color: AppColors.textSecondary(isDark)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              weightKg != null ? weightKg!.toStringAsFixed(0) : '—',
              style: AppTextStyles.heading3.copyWith(
                color: AppColors.textPrimary(isDark),
                fontSize: 22,
                height: 1,
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                'kg',
                style: AppTextStyles.monoSmall
                    .copyWith(color: AppColors.textSecondary(isDark)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GridCard extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String label;
  final List<Widget> children;

  const _GridCard({
    required this.isDark,
    required this.icon,
    required this.label,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? AppColors.darkOutlineVariant
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.outlineVariant(isDark)),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.outline(isDark),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }
}

/// FIX (audit M-5): empty-state card shown when a passport section (allergies,
/// medications, chronic conditions) has no data. Shows an icon, title,
/// helpful message, and a CTA button to add data.
class _EmptyStateCard extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String ctaLabel;
  final VoidCallback onCtaTap;

  const _EmptyStateCard({
    required this.isDark,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.ctaLabel,
    required this.onCtaTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border(isDark),
          width: 1,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'ClashDisplay',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: AppColors.textSecondary(isDark),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onCtaTap,
              icon: Icon(Icons.add, size: 18, color: AppColors.primary(isDark)),
              label: Text(
                ctaLabel,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary(isDark),
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final bool isDark;
  final String heading;
  final IconData headingIcon;
  final Color headingColor;
  final Widget? action;
  final Widget child;

  const _SectionCard({
    required this.isDark,
    required this.heading,
    required this.headingIcon,
    required this.headingColor,
    this.action,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? AppColors.darkOutlineVariant
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(headingIcon, size: 18, color: headingColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  heading,
                  style: AppTextStyles.subheading2
                      .copyWith(color: AppColors.textPrimary(isDark)),
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _AllergyChip extends StatelessWidget {
  final String label;
  final bool isDark;

  const _AllergyChip({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? AppColors.darkError.withValues(alpha: 0.18)
        : const Color(0xFFFFDAD6);
    final fg = isDark ? AppColors.darkError : const Color(0xFF93000A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.coronavirus_rounded, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}

class _MedicationRow extends StatelessWidget {
  final bool isDark;
  final String name;
  final String? dosage;
  final bool isActive;

  const _MedicationRow({
    required this.isDark,
    required this.name,
    required this.dosage,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer(isDark).withValues(alpha: isDark ? 0.3 : 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.medication_rounded,
                size: 18, color: AppColors.secondary(isDark)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.subheading2
                      .copyWith(color: AppColors.textPrimary(isDark)),
                ),
                if (dosage != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    dosage!,
                    style: AppTextStyles.monoSmall
                        .copyWith(color: AppColors.textSecondary(isDark)),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer(isDark),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isActive ? l10n.active.toUpperCase() : l10n.inactive.toUpperCase(),
              style: AppTextStyles.labelSmall.copyWith(
                color: isDark ? AppColors.darkOnSurface : const Color(0xFF326F59),
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Legacy info card — kept for chronic conditions + insurance so the existing
/// layout still works alongside the new sections above.
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? AppColors.darkOutlineVariant
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textSecondary(isDark),
          ),
        ),
        subtitle: Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary(isDark),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
