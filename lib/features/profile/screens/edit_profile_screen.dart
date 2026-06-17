import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../shared/theme/app_colors.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _allergyController = TextEditingController();
  final _conditionController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _emergencyRelationshipController = TextEditingController();

  DateTime? _dateOfBirth;
  String? _gender;
  String? _bloodType;
  List<String> _allergies = [];
  List<String> _chronicConditions = [];
  bool _isSaving = false;
  // Guards one-time field population so we don't clobber user edits on rebuild.
  bool _populated = false;

  static const _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  static const _genders = ['Male', 'Female', 'Other'];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _allergyController.dispose();
    _conditionController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyRelationshipController.dispose();
    super.dispose();
  }

  void _populateFields(UserProfile? profile) {
    if (profile == null) return;
    _nameController.text = profile.fullName ?? '';
    _emailController.text = profile.email;
    _dateOfBirth = profile.dateOfBirth;
    _bloodType = profile.bloodType;
    _gender = profile.gender;
    _allergies = List.from(profile.allergies);
    _chronicConditions = List.from(profile.chronicConditions);
    // Load height/weight back from the profile so the round-trip works.
    // Previously these fields were saved but never loaded, so re-editing
    // showed empty fields even when values were stored.
    if (profile.heightCm != null) {
      _heightController.text = profile.heightCm!.toStringAsFixed(0);
    }
    if (profile.weightKg != null) {
      _weightController.text = profile.weightKg!.toStringAsFixed(1);
    }
    if (profile.emergencyContacts.isNotEmpty) {
      _emergencyNameController.text = profile.emergencyContacts.first.name;
      _emergencyPhoneController.text = profile.emergencyContacts.first.phone;
      _emergencyRelationshipController.text = profile.emergencyContacts.first.relationship ?? '';
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  void _addAllergy() {
    final text = _allergyController.text.trim();
    if (text.isNotEmpty && !_allergies.contains(text)) {
      setState(() {
        _allergies.add(text);
        _allergyController.clear();
      });
    }
  }

  void _removeAllergy(String allergy) {
    setState(() => _allergies.remove(allergy));
  }

  void _addCondition() {
    final text = _conditionController.text.trim();
    if (text.isNotEmpty && !_chronicConditions.contains(text)) {
      setState(() {
        _chronicConditions.add(text);
        _conditionController.clear();
      });
    }
  }

  void _removeCondition(String condition) {
    setState(() => _chronicConditions.remove(condition));
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      final emergencyContacts = <Map<String, dynamic>>[];
      if (_emergencyNameController.text.trim().isNotEmpty) {
        emergencyContacts.add({
          'name': _emergencyNameController.text.trim(),
          'phone': _emergencyPhoneController.text.trim(),
          'relationship': _emergencyRelationshipController.text.trim(),
        });
      }

      final updateData = <String, dynamic>{
        'full_name': _nameController.text.trim(),
        // Send date as YYYY-MM-DD (DATE column type) instead of full ISO
        // timestamp, to avoid TZ surprises.
        'date_of_birth': _dateOfBirth?.toIso8601String().split('T')[0],
        'blood_type': _bloodType,
        'allergies': _allergies,
        'chronic_conditions': _chronicConditions,
        'emergency_contacts': emergencyContacts,
      };

      // Save gender — explicitly allow null so the user can clear the value.
      updateData['gender'] = _gender;

      // Save height/weight measurements. Explicitly allow null so the user
      // can clear the value by deleting the field contents.
      final heightText = _heightController.text.trim();
      final weightText = _weightController.text.trim();
      if (heightText.isNotEmpty) {
        final height = double.tryParse(heightText);
        if (height != null && height > 0 && height < 300) {
          updateData['height_cm'] = height;
        }
      } else {
        updateData['height_cm'] = null;
      }
      if (weightText.isNotEmpty) {
        final weight = double.tryParse(weightText);
        if (weight != null && weight > 0 && weight < 500) {
          updateData['weight_kg'] = weight;
        }
      } else {
        updateData['weight_kg'] = null;
      }

      final db = ref.read(databaseServiceProvider);
      await db.updateUserProfile(user.id, updateData);

      ref.invalidate(userProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile. Please try again.')),
        );
      }
      debugPrint('Profile update error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          // Populate fields once on first data arrival. Use a dedicated flag
          // instead of checking _nameController.text.isEmpty, because the
          // user may legitimately clear the name field while editing.
          if (!_populated && profile != null) {
            _populated = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _populateFields(profile);
              setState(() {});
            });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Avatar upload coming soon!')),
                        );
                      },
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: (AppColors.primary(isDark)).withValues(alpha: 0.12),
                            child: Text(
                              (_nameController.text.isNotEmpty ? _nameController.text : 'U')[0].toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'ClashDisplay',
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary(isDark),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.primary(isDark),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.surface(isDark),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Personal Info Section
                  _SectionLabel(label: 'Personal Information'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            style: const TextStyle(fontFamily: 'Inter'),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                              suffixIcon: Icon(Icons.lock_outline, size: 16),
                            ),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: AppColors.textSecondary(isDark),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Date of Birth
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.calendar_today_outlined),
                            title: Text(
                              _dateOfBirth != null
                                  ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                                  : 'Select Date of Birth',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: _dateOfBirth != null
                                    ? null
                                    : (AppColors.textSecondary(isDark)),
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _selectDate,
                          ),
                          const SizedBox(height: 8),
                          // Gender Dropdown
                          DropdownButtonFormField<String>(
                            value: _gender,
                            decoration: const InputDecoration(
                              labelText: 'Gender',
                              prefixIcon: Icon(Icons.wc_outlined),
                            ),
                            style: const TextStyle(fontFamily: 'Inter'),
                            items: _genders.map((g) => DropdownMenuItem(
                              value: g,
                              child: Text(g, style: const TextStyle(fontFamily: 'Inter')),
                            )).toList(),
                            onChanged: (v) => setState(() => _gender = v),
                          ),
                          const SizedBox(height: 16),
                          // Blood Type Dropdown
                          DropdownButtonFormField<String>(
                            value: _bloodType,
                            decoration: const InputDecoration(
                              labelText: 'Blood Type',
                              prefixIcon: Icon(Icons.bloodtype_outlined),
                            ),
                            style: const TextStyle(fontFamily: 'Inter'),
                            items: _bloodTypes.map((bt) => DropdownMenuItem(
                              value: bt,
                              child: Text(bt, style: const TextStyle(fontFamily: 'Inter')),
                            )).toList(),
                            onChanged: (v) => setState(() => _bloodType = v),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Measurements Section
                  _SectionLabel(label: 'Measurements'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _heightController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Height (cm)',
                                prefixIcon: Icon(Icons.height_outlined),
                              ),
                              style: const TextStyle(fontFamily: 'Inter'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _weightController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Weight (kg)',
                                prefixIcon: Icon(Icons.monitor_weight_outlined),
                              ),
                              style: const TextStyle(fontFamily: 'Inter'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Emergency Contact Section
                  _SectionLabel(label: 'Emergency Contact'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emergencyNameController,
                            decoration: const InputDecoration(
                              labelText: 'Contact Name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            style: const TextStyle(fontFamily: 'Inter'),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emergencyPhoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            style: const TextStyle(fontFamily: 'Inter'),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emergencyRelationshipController,
                            decoration: const InputDecoration(
                              labelText: 'Relationship',
                              prefixIcon: Icon(Icons.people_outline),
                              hintText: 'e.g. Spouse, Parent, Sibling',
                            ),
                            style: const TextStyle(fontFamily: 'Inter'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Allergies Section
                  _SectionLabel(label: 'Allergies'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _allergyController,
                                  decoration: const InputDecoration(
                                    labelText: 'Add Allergy',
                                    prefixIcon: Icon(Icons.add_circle_outline),
                                    isDense: true,
                                  ),
                                  style: const TextStyle(fontFamily: 'Inter'),
                                  onFieldSubmitted: (_) => _addAllergy(),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.add, color: AppColors.primary(isDark)),
                                onPressed: _addAllergy,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: _allergies.map((allergy) => Chip(
                              label: Text(allergy, style: const TextStyle(fontFamily: 'Inter', fontSize: 13)),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () => _removeAllergy(allergy),
                              backgroundColor: (AppColors.primary(isDark)).withValues(alpha: 0.08),
                              side: BorderSide(color: (AppColors.primary(isDark)).withValues(alpha: 0.3)),
                              labelStyle: TextStyle(color: AppColors.primary(isDark)),
                            )).toList(),
                          ),
                          if (_allergies.isEmpty)
                            Text(
                              'No allergies added',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: AppColors.textHint(isDark),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Chronic Conditions Section
                  _SectionLabel(label: 'Chronic Conditions'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _conditionController,
                                  decoration: const InputDecoration(
                                    labelText: 'Add Condition',
                                    prefixIcon: Icon(Icons.add_circle_outline),
                                    isDense: true,
                                  ),
                                  style: const TextStyle(fontFamily: 'Inter'),
                                  onFieldSubmitted: (_) => _addCondition(),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.add, color: AppColors.primary(isDark)),
                                onPressed: _addCondition,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: _chronicConditions.map((condition) => Chip(
                              label: Text(condition, style: const TextStyle(fontFamily: 'Inter', fontSize: 13)),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () => _removeCondition(condition),
                              backgroundColor: (isDark ? AppColors.darkWarning : AppColors.lightWarning).withValues(alpha: 0.08),
                              side: BorderSide(color: (isDark ? AppColors.darkWarning : AppColors.lightWarning).withValues(alpha: 0.3)),
                            )).toList(),
                          ),
                          if (_chronicConditions.isEmpty)
                            Text(
                              'No conditions added',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: AppColors.textHint(isDark),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary(isDark),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'DMSans',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textHint(isDark),
          letterSpacing: 1,
        ),
      ),
    );
  }
}
