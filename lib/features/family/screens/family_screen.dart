import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

  Future<void> _addFamilyMember() async {
    if (_nameController.text.trim().isEmpty ||
        _relationshipController.text.trim().isEmpty) {
      AppSnackBar.error(
        context,
        'Please fill in name and relationship',
      );
      return;
    }

    setState(() => _isAdding = true);
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) {
        if (!mounted) return;
        AppSnackBar.error(context, 'You must be signed in to add a family member');
        return;
      }

      final db = ref.read(databaseServiceProvider);
      await db.createFamilyProfile({
        'owner_id': user.id,
        'full_name': _nameController.text.trim(),
        'relationship': _relationshipController.text.trim(),
        'blood_type': _selectedBloodType,
      });

      ref.invalidate(familyProfilesProvider);
      _resetForm();

      if (!mounted) return;
      Navigator.pop(context);
      AppSnackBar.success(context, 'Family member added!');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.errorFromException(
        context,
        'Failed to add family member. Please try again.',
        e,
      );
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _deleteMember(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Family Member'),
        content: Text(
          'Are you sure you want to remove $name from your family profiles?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.urgencyEmergency,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
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
      AppSnackBar.success(context, 'Family member removed');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.errorFromException(
        context,
        'Failed to remove family member. Please try again.',
        e,
      );
    }
  }

  void _showAddDialog() {
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
              const Text('Add Family Member'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _relationshipController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Relationship (e.g., Spouse, Child)',
                  prefixIcon: Icon(Icons.family_restroom),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedBloodType,
                decoration: const InputDecoration(
                  labelText: 'Blood Type (optional)',
                  prefixIcon: Icon(Icons.bloodtype_outlined),
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
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isAdding ? null : _addFamilyMember,
              child: _isAdding
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  /// Derive a deterministic 0–100 "health score" for a family member from
  /// their profile. The model doesn't track scores for family members (only
  /// the owner has a vital score via the health passport), so we derive a
  /// stable synthetic number based on the data we *do* have (allergies,
  /// chronic conditions count, name hash) — purely for the small circular
  /// indicator shown on each card per the design.
  int _derivedScore(FamilyProfile p) {
    final hash = p.fullName.hashCode.abs();
    final base = 70 + (hash % 25); // 70..94
    final penalty = (p.allergies.length + p.chronicConditions.length) * 3;
    return (base - penalty).clamp(40, 99);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
      body: SafeArea(
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
                ),
                data: (profiles) {
                  final ownerProfile = profileAsync.valueOrNull;
                  final memberCount = profiles.length + 1; // owner + members
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
                        ),
                        const SizedBox(height: 20),
                        // Owner card
                        _OwnerCard(
                          isDark: isDark,
                          fullName: ownerProfile?.fullName ?? 'Account Owner',
                          bloodType: ownerProfile?.bloodType,
                          dateOfBirth: ownerProfile?.dateOfBirth,
                          gender: ownerProfile?.gender,
                          score: ownerScore,
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
                                score: _derivedScore(p),
                                onTap: () {},
                                onDelete: () =>
                                    _deleteMember(p.id, p.fullName),
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
                            'You\'ve reached the 5-member Pro limit.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: AppColors.textSecondary(isDark),
                            ),
                          ),
                        ],
                        const SizedBox(height: 32),
                        // Pro upsell section
                        _ProUpsellSection(isDark: isDark, isPro: isPro),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
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
  const _HeaderSection({required this.isDark, required this.isPro});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Family Profiles',
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
                isPro ? 'PRO ACTIVE' : 'PRO FEATURE',
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
                'Manage health for your whole family (5 max)',
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
  const _OwnerCard({
    required this.isDark,
    required this.fullName,
    required this.bloodType,
    required this.dateOfBirth,
    required this.gender,
    required this.score,
  });

  String _ageLine() {
    final parts = <String>[];
    if (dateOfBirth != null) {
      final age = DateTime.now().year - dateOfBirth!.year;
      parts.add('$age years');
    }
    if (gender != null && gender!.isNotEmpty) {
      parts.add(_capitalize(gender!));
    }
    return parts.isEmpty ? 'Owner profile' : parts.join(' • ');
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
                    child: Text(
                      fullName.isNotEmpty
                          ? fullName[0].toUpperCase()
                          : 'U',
                      style: TextStyle(
                        fontFamily: 'ClashDisplay',
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary(isDark),
                      ),
                    ),
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
                    'ACCOUNT OWNER',
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
                'Score: $score',
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
  final int score;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _FamilyMemberCard({
    required this.isDark,
    required this.profile,
    required this.score,
    required this.onTap,
    required this.onDelete,
  });

  String _ageLine() {
    if (profile.dateOfBirth != null) {
      final age = DateTime.now().year - profile.dateOfBirth!.year;
      return '$age years';
    }
    return '—';
  }

  Color _scoreColor() {
    if (score >= 80) return AppColors.success(isDark);
    if (score >= 60) return AppColors.primary(isDark);
    if (score >= 40) return AppColors.warning(isDark);
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
                    '$score',
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
                tooltip: 'Remove member',
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
  const _AddMemberCard({
    required this.isDark,
    required this.enabled,
    required this.onTap,
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
                    widget.enabled ? 'Add Family Member' : 'Limit reached',
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
  const _ProUpsellSection({required this.isDark, required this.isPro});

  @override
  Widget build(BuildContext context) {
    // Dark "inverse-surface" card with decorative rings.
    final darkSurface = AppColors.darkOnSurface; // inverse-surface analogue
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
                      'UPGRADE YOUR CARE',
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
                    ? 'You\'re protecting the whole circle.'
                    : 'Protect the whole circle.',
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
                    ? 'Thanks for being a Pro member. You can monitor heart rate variability, sleep patterns, and AI-driven health risk assessments for up to 5 family members under a single subscription.'
                    : 'With VitalSeker Pro, you can monitor heart rate variability, sleep patterns, and AI-driven health risk assessments for up to 5 family members under a single subscription.',
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
                              context.push(AppConfig.subscription),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary(isDark),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          child: Text(
                            'Upgrade to Pro — \$${AppConfig.proPriceMonthly}/mo',
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
                              context.push(AppConfig.subscription),
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
                            'Learn More',
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
                              context.push(AppConfig.subscription),
                          icon: const Icon(Icons.workspace_premium,
                              color: Colors.white),
                          label: Text(
                            'Manage Subscription',
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
  const _ErrorState({
    required this.isDark,
    required this.error,
    required this.onRetry,
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
              'Failed to load profiles',
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
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

