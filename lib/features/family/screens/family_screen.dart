import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/family_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../shared/theme/app_colors.dart';

class FamilyScreen extends ConsumerStatefulWidget {
  const FamilyScreen({super.key});

  @override
  ConsumerState<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends ConsumerState<FamilyScreen> {
  final _nameController = TextEditingController();
  final _relationshipController = TextEditingController();
  // Use a plain nullable String for the dropdown value. Previously the code
  // used _bloodTypeController.text as the DropdownButtonFormField value, but
  // updating the controller's text doesn't trigger a rebuild, so the dropdown
  // visually stayed on its old value until something else caused a rebuild.
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
    if (_nameController.text.trim().isEmpty || _relationshipController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in name and relationship')),
      );
      return;
    }

    setState(() => _isAdding = true);
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be signed in to add a family member')),
        );
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Family member added!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to add family member. Please try again.'),
          backgroundColor: AppColors.error(Theme.of(context).brightness == Brightness.dark),
        ),
      );
      debugPrint('Family add error: $e');
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _deleteMember(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Family Member'),
        content: Text('Are you sure you want to remove $name from your family profiles?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.urgencyEmergency),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Family member removed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove family member. Please try again.')),
      );
      debugPrint('Family delete error: $e');
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
                  color: (AppColors.primary(isDark)).withValues(alpha: 0.12),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profilesAsync = ref.watch(familyProfilesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Family Profiles')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: AppColors.primary(isDark),
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
      body: profilesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
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
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$e',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.textSecondary(isDark),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(familyProfilesProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (profiles) {
          if (profiles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.family_restroom, size: 80, color: isDark ? AppColors.grey600 : AppColors.grey300),
                  const SizedBox(height: 16),
                  Text(
                    'No Family Members Yet',
                    style: TextStyle(
                      fontFamily: 'ClashDisplay',
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add family members to manage their\nhealth profiles alongside yours',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: AppColors.textHint(isDark),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: profiles.length,
            itemBuilder: (context, index) {
              final profile = profiles[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: (AppColors.primary(isDark)).withValues(alpha: 0.12),
                    child: Text(
                      profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontFamily: 'ClashDisplay',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary(isDark),
                      ),
                    ),
                  ),
                  title: Text(
                    profile.fullName,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    profile.relationship,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (profile.bloodType != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.urgencyEmergency.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            profile.bloodType!,
                            style: const TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.urgencyEmergency,
                            ),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.urgencyEmergency),
                        onPressed: () => _deleteMember(profile.id, profile.fullName),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
