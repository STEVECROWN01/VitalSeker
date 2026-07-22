import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/family_profile.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/family_provider.dart';
import '../../../core/providers/health_passport_provider.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Family Profiles screen — redesigned to match the Google Stitch UI design.
///
/// Layout (top → bottom):
///   1. Compact app bar (back + "VitalSeker" + profile avatar).
///   2. Header: "Family Profiles" headline + "PRO FEATURE" pill + subtitle
///      "Manage health for your whole family (5 max)".
///   3. Family grid (single column on mobile, multi on tablet):
///      - Owner card (gradient border, large avatar + verified badge +
///        "Account Owner" label + per-member score).
///      - Family member cards (avatar + name + relationship + age + small
///        circular score indicator).
///      - "Add Family Member" dashed card with pulse-glow animation (replaces
///        the old FloatingActionButton).
///   4. Pro upsell section: dark card (inverse-surface bg), "Protect the
///      whole circle." headline, "Upgrade to Pro — $6.99/mo" button.
///
/// Existing functionality preserved:
///   - Add-family-member dialog (full name, relationship, optional blood type).
///   - Delete-family-member flow with confirmation dialog.
///   - Blood-type badge display on each card.
class FamilyScreen extends ConsumerStatefulWidget {
  const FamilyScreen({super.key});

  @override
  ConsumerState<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends ConsumerState<FamilyScreen> {
  final _nameController = TextEditingController();
  final _relationshipController = TextEditingController();
  // Plain nullable String for the dropdown value (controller.text doesn't
  // trigger rebuilds).
  String? _selectedBloodType;
  bool _isAdding = false;

  static const List<String> _bloodTypeOptions = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _nameController.clear();
    _relationshipController.clear();
    _selectedBloodType = null;
  }

  Future<void> _addFamilyMember(void Function(void Function()) setDialogState) async {
    final l10n = AppLocalizations.of(context)!;

    // ── Pro-gating (authoritative) ──
    // Uses `isProUserAsyncProvider` which checks BOTH the DB subscriptions
    // row AND RevenueCat's SDK directly. This ensures paying users are
    // never blocked by a DB sync delay — the original bug was that the
    // family-add flow only checked the DB, so users who had paid via
    // RevenueCat but whose `subscriptions` row hadn't synced yet were
    // incorrectly rejected.
    final isPro = await ref.read(isProUserAsyncProvider.future);
    if (!isPro) {
      if (!mounted) return;
      AppSnackBar.error(
        context,
        l10n.familyProfilesProOnly,
      );
      context.push(AppConfig.proPlan);
      return;
    }

    if (_nameController.text.trim().isEmpty ||
        _relationshipController.text.trim().isEmpty) {
      AppSnackBar.error(
        context,
        l10n.pleaseFillNameRelationship,
      );
      return;
    }

    // FIX (audit H-21): the previous code called setState on the PARENT
    // widget, but the dialog uses StatefulBuilder with its own setDialogState.
    // The dialog's button never showed the loading spinner and stayed enabled,
    // allowing the user to tap "Add" multiple times and create duplicates.
    // We now accept the setDialogState callback and use it to update the
    // dialog's loading state directly.
    setDialogState(() {});
    setState(() => _isAdding = true);
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) {
        if (!mounted) return;
        AppSnackBar.error(context, l10n.mustBeSignedInToAddFamily);
        return;
      }

      final db = ref.read(databaseServiceProvider);
      final payload = <String, dynamic>{
        'owner_id': user.id,
        'full_name': _nameController.text.trim(),
        'relationship': _relationshipController.text.trim(),
      };
      if (_selectedBloodType != null && _selectedBloodType!.isNotEmpty) {
        payload['blood_type'] = _selectedBloodType;
      }

      try {
        await db.createFamilyProfile(payload);
      } catch (insertError) {
        debugPrint('[Family] createFamilyProfile failed. Payload: $payload');
        debugPrint('[Family] Insert error: $insertError');
        rethrow;
      }

      ref.invalidate(familyProfilesProvider);
      _resetForm();

      if (!mounted) return;
      Navigator.pop(context);
      AppSnackBar.success(context, l10n.familyMemberAdded);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.errorFromException(
        context,
        l10n.failedToAddFamily,
        e,
      );
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
        // Rebuild the dialog so the button exits its loading state.
        setDialogState(() {});
      }
    }
  }

  Future<void> _deleteMember(String id, String name) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.removeFamilyMember),
        content: Text(
          l10n.removeFamilyMemberConfirm(name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.urgencyEmergency,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.remove),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final db = ref.read(databaseServiceProvider);
      await db.deleteFamilyProfile(id);
      ref.invalidate(familyProfilesProvider);
      if (!mounted) return;
      AppSnackBar.success(context, l10n.familyMemberRemoved);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.errorFromException(
        context,
        l10n.failedToRemoveFamily,
        e,
      );
    }
  }

  /// Show a read-only bottom sheet with the family member's details when
  /// their card is tapped. Previously tapping the card did nothing (empty
  /// onTap handler), which was confusing — the card visually responded to
  /// taps (ripple effect) but no UI appeared.
  void _showMemberDetails(FamilyProfile p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant(isDark),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primaryContainer(isDark),
                    child: Text(
                      p.fullName.isNotEmpty ? p.fullName[0].toUpperCase() : '?',
                      style: TextStyle(color: AppColors.primary(isDark)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.fullName,
                            style: TextStyle(
                              fontFamily: 'ClashDisplay',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary(isDark),
                            )),
                        if (p.relationship.isNotEmpty)
                          Text(p.relationship,
                              style: TextStyle(
                                fontFamily: 'DMSans',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.05,
                                color: AppColors.textSecondary(isDark),
                              )),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (p.bloodType != null && p.bloodType!.isNotEmpty)
                _DetailRow(label: l10n.bloodType, value: p.bloodType!, isDark: isDark),
              if (p.dateOfBirth != null)
                _DetailRow(
                  label: l10n.dateOfBirth,
                  value: '${p.dateOfBirth!.year}-${p.dateOfBirth!.month.toString().padLeft(2, '0')}-${p.dateOfBirth!.day.toString().padLeft(2, '0')}',
                  isDark: isDark,
                ),
              if (p.allergies.isNotEmpty)
                _DetailRow(label: l10n.allergies, value: p.allergies.join(', '), isDark: isDark),
              if (p.chronicConditions.isNotEmpty)
                _DetailRow(label: l10n.chronicConditions, value: p.chronicConditions.join(', '), isDark: isDark),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddDialog() {
    final l10n = AppLocalizations.of(context)!;
    // Reset form state each time the dialog opens so stale values from a
    // previous open don't persist.
    _resetForm();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary(isDark).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.person_add, color: AppColors.primary(isDark), size: 20),
              ),
              const SizedBox(width: 12),
              Text(l10n.addFamilyMember),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.fullNameLabel,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _relationshipController,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l10n.relationshipExample,
                  prefixIcon: const Icon(Icons.family_restroom),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                dropdownColor: AppColors.surface(isDark),
                style: TextStyle(color: AppColors.textPrimary(isDark)),
                value: _selectedBloodType,
                decoration: InputDecoration(
                  labelText: l10n.bloodTypeOptional,
                  prefixIcon: const Icon(Icons.bloodtype_outlined),
                ),
                items: _bloodTypeOptions.map((type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type, style: const TextStyle(fontFamily: 'Inter', fontSize: 16)),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() => _selectedBloodType = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: _isAdding ? null : () => _addFamilyMember(setDialogState),
              child: _isAdding
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.add),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns null because the family member health score is NOT tracked in
  /// the data model — only the owner has a vital score via the health
  /// passport. The previous implementation fabricated a deterministic number
  /// from `p.fullName.hashCode` which was deceptive (parents thought the
  /// score reflected their child's actual health). Now we return null and
  /// the card shows a "—" placeholder until real scores are tracked.
  int? _familyMemberScore(FamilyProfile p) => null;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final profilesAsync = ref.watch(familyProfilesProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final passportAsync = ref.watch(healthPassportProvider);
    // Watched for state-management continuity — the Pro upsell section
    // shows different copy if the user is already Pro.
    final isPro = ref.watch(isProUserProvider);

    final ownerScore = passportAsync.maybeWhen(
      data: (p) => p?.vitalScore ?? 0,
      orElse: () => 0,
    );

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      // No FAB — the design uses a dashed "Add Family Member" card in-flow.
      // FIX: add RefreshIndicator for pull-to-refresh.
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(familyProfilesProvider);
          await ref.read(familyProfilesProvider.future);
        },
        child: SafeArea(
        child: Column(
          children: [
            // ── Top app bar ──
            _TopBar(
              isDark: isDark,
              profileAsync: profileAsync,
            ),
            // ── Body ──
            Expanded(
              child: profilesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorState(
                  isDark: isDark,
                  error: e,
                  onRetry: () => ref.invalidate(familyProfilesProvider),
                  l10n: l10n,
                ),
                data: (profiles) {
                  final ownerProfile = profileAsync.valueOrNull;
                  // Spec: "Profils Famille (Pro): Jusqu'à 5 profils familiaux"
                  // = up to 5 family member profiles (NOT counting the owner).
                  final memberCount = profiles.length;
                  final isAtLimit = memberCount >= 5;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header section
                        _HeaderSection(
                          isDark: isDark,
                          isPro: isPro,
                          l10n: l10n,
                        ),
                        const SizedBox(height: 20),
                        // Owner card
                        _OwnerCard(
                          isDark: isDark,
                          fullName: ownerProfile?.fullName ?? l10n.accountOwnerDefault,
                          bloodType: ownerProfile?.bloodType,
                          dateOfBirth: ownerProfile?.dateOfBirth,
                          gender: ownerProfile?.gender,
                          score: ownerScore,
                          l10n: l10n,
                          avatarUrl: ownerProfile?.avatarUrl,
                        )
                            .animate()
                            .slideY(duration: 400.ms, begin: 0.1)
                            .fadeIn(duration: 350.ms),
                        const SizedBox(height: 12),
                        // Family member cards
                        ...profiles.map((p) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _FamilyMemberCard(
                                isDark: isDark,
                                profile: p,
                                score: _familyMemberScore(p),
                                // Show a bottom sheet with member details when
                                // tapped. Previously this was `() {}` — the
                                // card visually responded to taps (ripple)
                                // but did nothing, which was confusing.
                                onTap: () => _showMemberDetails(p),
                                onDelete: () =>
                                    _deleteMember(p.id, p.fullName),
                                l10n: l10n,
                              )
                                  .animate()
                                  .slideY(
                                    duration: 400.ms,
                                    begin: 0.1,
                                    delay: 80.ms,
                                  )
                                  .fadeIn(
                                    duration: 350.ms,
                                    delay: 80.ms,
                                  ),
                            )),
                        // Add-family-member dashed card (pulse-glow animation)
                        _AddMemberCard(
                          isDark: isDark,
                          enabled: !isAtLimit,
                          onTap: _showAddDialog,
                          l10n: l10n,
                        )
                            .animate()
                            .slideY(
                              duration: 400.ms,
                              begin: 0.1,
                              delay: 160.ms,
                            )
                            .fadeIn(
                              duration: 350.ms,
                              delay: 160.ms,
                            ),
                        if (isAtLimit) ...[
                          const SizedBox(height: 8),
                          Text(
                            l10n.reachedProLimit,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: AppColors.textSecondary(isDark),
                            ),
                          ),
                        ],
                        const SizedBox(height: 32),
                        // Pro upsell section
                        _ProUpsellSection(isDark: isDark, isPro: isPro, l10n: l10n),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Top app bar
// ═══════════════════════════════════════════════════════════════════════════

class _TopBar extends StatelessWidget {
  final bool isDark;
  final AsyncValue<dynamic> profileAsync;
  const _TopBar({required this.isDark, required this.profileAsync});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark).withValues(alpha: 0.96),
        border: Border(
          bottom: BorderSide(
            color: AppColors.borderLight(isDark).withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            color: AppColors.primary(isDark),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Text(
            'VitalSeker',
            style: TextStyle(
              fontFamily: 'ClashDisplay',
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.primary(isDark),
              letterSpacing: -0.01,
              height: 1.15,
            ),
          ),
          const Spacer(),
          // Profile avatar circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryContainer(isDark),
              border: Border.all(
                color: AppColors.surface(isDark),
                width: 2,
              ),
            ),
            child: profileAsync.maybeWhen(
              data: (p) {
                final name = p?.fullName ?? 'U';
                final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
                final avatarUrl = p?.avatarUrl;
                if (avatarUrl != null && avatarUrl.isNotEmpty) {
                  return ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: avatarUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Center(
                        child: Text(
                          initial,
                          style: TextStyle(
                            fontFamily: 'ClashDisplay',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary(isDark),
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontFamily: 'ClashDisplay',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary(isDark),
                    ),
                  ),
                );
              },
              orElse: () => Icon(
                Icons.person,
                size: 20,
                color: AppColors.primary(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Header section: title + PRO FEATURE pill + subtitle
// ═══════════════════════════════════════════════════════════════════════════

class _HeaderSection extends StatelessWidget {
  final bool isDark;
  final bool isPro;
  final AppLocalizations l10n;
  const _HeaderSection({required this.isDark, required this.isPro, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.familyProfiles,
          style: TextStyle(
            fontFamily: 'ClashDisplay',
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary(isDark),
            letterSpacing: -0.01,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary(isDark).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                isPro ? l10n.proActive : l10n.proFeature,
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary(isDark),
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.manageHealthWholeFamily,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.textSecondary(isDark),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Owner card with gradient border + verified badge
// ═══════════════════════════════════════════════════════════════════════════

class _OwnerCard extends StatelessWidget {
  final bool isDark;
  final String fullName;
  final String? bloodType;
  final DateTime? dateOfBirth;
  final String? gender;
  final int score;
  final AppLocalizations l10n;
  final String? avatarUrl;
  const _OwnerCard({
    required this.isDark,
    required this.fullName,
    required this.bloodType,
    required this.dateOfBirth,
    required this.gender,
    required this.score,
    required this.l10n,
    this.avatarUrl,
  });

  String _ageLine() {
    final parts = <String>[];
    if (dateOfBirth != null) {
      // Correct age calculation — accounts for whether the birthday has
      // occurred this year. The previous `now.year - dob.year` was wrong by
      // up to 1 year for anyone whose birthday hasn't happened yet this year.
      final now = DateTime.now();
      final dob = dateOfBirth!;
      int age = now.year - dob.year;
      if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
        age--;
      }
      if (age >= 0) {
        parts.add(l10n.years(age));
      }
    }
    if (gender != null && gender!.isNotEmpty) {
      parts.add(_capitalize(gender!));
    }
    return parts.isEmpty ? l10n.ownerProfile : parts.join(' • ');
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: AppColors.brandGradientFor(isDark),
      ),
      padding: const EdgeInsets.all(2), // gradient border thickness
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // Avatar with verified badge
            Stack(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryContainer(isDark),
                    border: Border.all(
                      color: AppColors.primary(isDark),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Builder(builder: (context) {
                      final name = fullName.isNotEmpty ? fullName : 'U';
                      final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
                      if (avatarUrl != null && avatarUrl!.isNotEmpty) {
                        return ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: avatarUrl!,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Text(
                              initial,
                              style: TextStyle(
                                fontFamily: 'ClashDisplay',
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary(isDark),
                              ),
                            ),
                          ),
                        );
                      }
                      return Text(
                        initial,
                        style: TextStyle(
                          fontFamily: 'ClashDisplay',
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary(isDark),
                        ),
                      );
                    }),
                  ),
                ),
                Positioned(
                  bottom: -1,
                  right: -1,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.primary(isDark),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.surface(isDark),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.verified,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            // Name + role + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(isDark),
                      height: 1.2,
                      letterSpacing: -0.01,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.accountOwner,
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary(isDark),
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _ageLine(),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: AppColors.textSecondary(isDark),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (bloodType != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.urgencyEmergency
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            bloodType!,
                            style: TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.urgencyEmergency,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Score badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer(isDark),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                l10n.scoreValue(score),
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary(isDark),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Family member card with circular score indicator
// ═══════════════════════════════════════════════════════════════════════════

class _FamilyMemberCard extends StatelessWidget {
  final bool isDark;
  final FamilyProfile profile;
  /// Family member health score. Null when no real score is tracked (which is
  /// always, currently — see _familyMemberScore comment). The card shows a
  /// "—" placeholder in that case instead of a fabricated number.
  final int? score;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final AppLocalizations l10n;
  const _FamilyMemberCard({
    required this.isDark,
    required this.profile,
    required this.score,
    required this.onTap,
    required this.onDelete,
    required this.l10n,
  });

  String _ageLine() {
    if (profile.dateOfBirth != null) {
      // Correct age calculation — accounts for whether the birthday has
      // occurred this year. The previous `now.year - dob.year` was wrong by
      // up to 1 year for anyone whose birthday hasn't happened yet this year.
      final now = DateTime.now();
      final dob = profile.dateOfBirth!;
      int age = now.year - dob.year;
      if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
        age--;
      }
      if (age < 0) return '—';
      return l10n.years(age);
    }
    return '—';
  }

  Color _scoreColor() {
    if (score == null) return AppColors.outline(isDark);
    if (score! >= 80) return AppColors.success(isDark);
    if (score! >= 60) return AppColors.primary(isDark);
    if (score! >= 40) return AppColors.warning(isDark);
    return AppColors.error(isDark);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface(isDark),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface(isDark),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight(isDark)),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryContainer(isDark).withValues(alpha: 0.4),
                ),
                child: Center(
                  child: Text(
                    profile.fullName.isNotEmpty
                        ? profile.fullName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontFamily: 'ClashDisplay',
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary(isDark),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Name + relationship + meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(isDark),
                        height: 1.2,
                        letterSpacing: -0.01,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile.relationship.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary(isDark),
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _ageLine(),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: AppColors.textSecondary(isDark),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (profile.bloodType != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.urgencyEmergency
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              profile.bloodType!,
                              style: TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.urgencyEmergency,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Score circle (small circular indicator)
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _scoreColor(),
                    width: 4,
                  ),
                ),
                child: Center(
                  child: Text(
                    // Show "—" when no real score is tracked (was previously
                    // a fabricated number from the user's name hash).
                    score == null ? '—' : '$score',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary(isDark),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Delete action
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: AppColors.urgencyEmergency,
                tooltip: l10n.removeMember,
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Add-member dashed card with pulse-glow animation
// ═══════════════════════════════════════════════════════════════════════════

class _AddMemberCard extends StatefulWidget {
  final bool isDark;
  final bool enabled;
  final VoidCallback onTap;
  final AppLocalizations l10n;
  const _AddMemberCard({
    required this.isDark,
    required this.enabled,
    required this.onTap,
    required this.l10n,
  });

  @override
  State<_AddMemberCard> createState() => _AddMemberCardState();
}

class _AddMemberCardState extends State<_AddMemberCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppColors.primary(widget.isDark);
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, _) {
        // Pulse ring alpha: 0.0 -> 0.4 -> 0.0 over the cycle.
        final t = _pulseAnimation.value;
        final ringAlpha = 0.4 * (1 - t);
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.enabled ? widget.onTap : null,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 104),
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                color: widget.enabled
                    ? AppColors.primary(widget.isDark).withValues(alpha: 0.03)
                    : AppColors.subtleBackground(widget.isDark),
                borderRadius: BorderRadius.circular(16),
                // No solid border — the dashed border is drawn via
                // `foregroundDecoration` below.
                boxShadow: widget.enabled
                    ? [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: ringAlpha),
                          blurRadius: 10 + (t * 10),
                          spreadRadius: t * 4,
                          offset: Offset.zero,
                        ),
                      ]
                    : null,
              ),
              foregroundDecoration: _DashedBorderDecoration(
                color: widget.enabled
                    ? AppColors.outlineVariant(widget.isDark)
                    : AppColors.outlineVariant(widget.isDark)
                        .withValues(alpha: 0.4),
                width: 2,
                radius: 16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_circle,
                    size: 30,
                    color: widget.enabled
                        ? AppColors.primary(widget.isDark)
                        : AppColors.textTertiary(widget.isDark),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.enabled ? widget.l10n.addFamilyMember : widget.l10n.limitReached,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: widget.enabled
                          ? AppColors.primary(widget.isDark)
                          : AppColors.textTertiary(widget.isDark),
                      letterSpacing: -0.01,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Custom decoration that paints a dashed rectangle border.
class _DashedBorderDecoration extends Decoration {
  final Color color;
  final double width;
  final double radius;
  const _DashedBorderDecoration({
    required this.color,
    required this.width,
    required this.radius,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _DashedBorderPainter(
      color: color,
      width: width,
      radius: radius,
    );
  }
}

class _DashedBorderPainter extends BoxPainter {
  final Color color;
  final double width;
  final double radius;
  _DashedBorderPainter({
    required this.color,
    required this.width,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size ?? Size.zero;
    final rect = offset & size;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height),
      Radius.circular(radius),
    );

    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Build a dashed path around the rounded rectangle by walking the
    // PathMetric and emitting alternating dash/gap segments.
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    const dashWidth = 8.0;
    const gapWidth = 6.0;
    final dashedPath = Path();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        // PathMetric.extractPath returns a sub-path from `distance` to `end`.
        final segment = metric.extractPath(distance, end);
        dashedPath.addPath(segment, Offset.zero);
        distance += dashWidth + gapWidth;
      }
    }
    canvas.drawPath(dashedPath, paint);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Pro upsell section
// ═══════════════════════════════════════════════════════════════════════════

class _ProUpsellSection extends StatelessWidget {
  final bool isDark;
  final bool isPro;
  final AppLocalizations l10n;
  const _ProUpsellSection({required this.isDark, required this.isPro, required this.l10n});

  @override
  Widget build(BuildContext context) {
    // Dark "inverse-surface" card with decorative rings.
    //
    // NB: `AppColors.darkOnSurface` (#E1E3E0) is a LIGHT color (it's the
    // *on-surface* text color used in dark mode), so using it as a card
    // background produced a light card with `Colors.white` text on top —
    // unreadable in both light and dark mode. We use `darkBackground`
    // (#050F0B, Deep Forest) instead, which is genuinely dark in both
    // modes and matches the original design intent ("dark inverse-surface").
    final darkSurface = AppColors.darkBackground;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: darkSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative rings
          Positioned(
            bottom: -60,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF7CD8B3).withValues(alpha: 0.06),
                  width: 18,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            right: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF7CD8B3).withValues(alpha: 0.1),
                  width: 10,
                ),
              ),
            ),
          ),
          // Top-right glow
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    AppColors.primary(isDark).withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Upgrade badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary(isDark).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.primary(isDark).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: const Color(0xFF7CD8B3),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.upgradeYourCare,
                      style: TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF7CD8B3),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Headline
              Text(
                isPro
                    ? l10n.protectingWholeCircle
                    : l10n.protectWholeCircle,
                style: TextStyle(
                  fontFamily: 'ClashDisplay',
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.15,
                  letterSpacing: -0.01,
                ),
              ),
              const SizedBox(height: 12),
              // Body
              Text(
                isPro
                    ? l10n.proMemberThanks
                    : l10n.proUpsellBody,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: const Color(0xFFBFC9C2),
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 20),
              // Buttons
              if (!isPro) ...[
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () =>
                              context.push(AppConfig.proPlan),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary(isDark),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          child: Text(
                            l10n.upgradeToProPrice('\$${AppConfig.proPriceMonthly}'),
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.01,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: () =>
                              context.push(AppConfig.proPlan),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.08),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          child: Text(
                            l10n.learnMore,
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              context.push(AppConfig.proPlan),
                          icon: const Icon(Icons.workspace_premium,
                              color: Colors.white),
                          label: Text(
                            l10n.manageSubscription,
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.08),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Error state (preserved)
// ═══════════════════════════════════════════════════════════════════════════

class _ErrorState extends StatelessWidget {
  final bool isDark;
  final Object error;
  final VoidCallback onRetry;
  final AppLocalizations l10n;
  const _ErrorState({
    required this.isDark,
    required this.error,
    required this.onRetry,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.urgencyEmergency),
            const SizedBox(height: 16),
            Text(
              l10n.failedToLoadProfiles,
              style: TextStyle(
                fontFamily: 'ClashDisplay',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppColors.textSecondary(isDark),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}


/// Helper row for the member details bottom sheet.
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  const _DetailRow({required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.05,
                color: AppColors.textSecondary(isDark),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppColors.textPrimary(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
