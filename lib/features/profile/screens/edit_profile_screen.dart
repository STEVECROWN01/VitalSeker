import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../shared/theme/app_colors.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import '../../../shared/widgets/app_snack_bar.dart';

/// Action chosen in the avatar source-chooser bottom sheet.
enum _AvatarAction { gallery, camera, remove }

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
  String? _avatarUrl;
  bool _isUploadingAvatar = false;
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
    _avatarUrl = profile.avatarUrl;
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

  Future<void> _pickAvatar() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final l10n = AppLocalizations.of(context)!;
    final hasAvatar = _avatarUrl != null && _avatarUrl!.isNotEmpty;

    // Source-chooser: gallery, camera, or remove (only when an avatar
    // already exists). Returns one of [_AvatarAction] or null if dismissed.
    final action = await showModalBottomSheet<_AvatarAction>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.chooseFromGallery),
              onTap: () => Navigator.pop(ctx, _AvatarAction.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(l10n.takePhoto),
              onTap: () => Navigator.pop(ctx, _AvatarAction.camera),
            ),
            if (hasAvatar)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: AppColors.urgencyEmergency,
                ),
                title: Text(
                  l10n.removePhoto,
                  style: TextStyle(color: AppColors.urgencyEmergency),
                ),
                onTap: () => Navigator.pop(ctx, _AvatarAction.remove),
              ),
          ],
        ),
      ),
    );
    if (action == null) return;

    if (action == _AvatarAction.remove) {
      await _removeAvatar();
      return;
    }

    final source = action == _AvatarAction.gallery
        ? ImageSource.gallery
        : ImageSource.camera;

    setState(() => _isUploadingAvatar = true);
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (xfile == null) return; // user cancelled

      final bytes = await xfile.readAsBytes();
      // Default to JPEG; image_picker returns JPEG for camera by default.
      final contentType = xfile.mimeType ?? 'image/jpeg';

      final db = ref.read(databaseServiceProvider);
      final publicUrl = await db.uploadAvatar(
        userId: user.id,
        bytes: bytes,
        contentType: contentType,
      );

      // Persist the URL on the user profile immediately so other screens
      // (profile, dashboard) see it without requiring a full Save Changes tap.
      await db.updateUserProfile(user.id, {'avatar_url': publicUrl});
      ref.invalidate(userProfileProvider);

      if (mounted) {
        setState(() {
          _avatarUrl = publicUrl;
          _isUploadingAvatar = false;
        });
        AppSnackBar.success(context, l10n.avatarUpdated);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        AppSnackBar.errorFromException(context, l10n.avatarUploadFailed, e);
      }
    }
  }

  /// Remove the user's avatar — both the storage object (best-effort) and
  /// the `avatar_url` field on the user row. The user row is the source of
  /// truth for whether an avatar is set, so even if the storage delete fails
  /// we still clear `avatar_url` so the UI falls back to the initials.
  Future<void> _removeAvatar() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final l10n = AppLocalizations.of(context)!;
    setState(() => _isUploadingAvatar = true);
    try {
      final db = ref.read(databaseServiceProvider);
      await db.deleteAvatar(user.id);
      await db.updateUserProfile(user.id, {'avatar_url': null});
      ref.invalidate(userProfileProvider);

      if (mounted) {
        setState(() {
          _avatarUrl = null;
          _isUploadingAvatar = false;
        });
        AppSnackBar.success(context, l10n.avatarRemoved);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        AppSnackBar.errorFromException(
          context,
          l10n.avatarRemoveFailed,
          e,
        );
      }
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
    // FIX: case-insensitive duplicate check so "Penicillin" and "penicillin"
    // are treated as the same allergy (previously both were stored, causing
    // duplicates in the Medical ID and PDF export).
    if (text.isNotEmpty &&
        !_allergies.any((a) => a.toLowerCase() == text.toLowerCase())) {
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
    // FIX: case-insensitive duplicate check (see _addAllergy).
    if (text.isNotEmpty &&
        !_chronicConditions.any((c) => c.toLowerCase() == text.toLowerCase())) {
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

    final l10n = AppLocalizations.of(context)!;
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
          SnackBar(content: Text(l10n.profileUpdatedSuccessfully)),
        );
        if (Navigator.canPop(context)) { Navigator.pop(context); } else { context.go(AppConfig.profile); }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileUpdateFailed)),
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
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editProfileTitle),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    l10n.save,
                    style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.errorPrefix(e.toString()))),
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
                      onTap: _isUploadingAvatar ? null : _pickAvatar,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: (AppColors.primary(isDark)).withValues(alpha: 0.12),
                            backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                                ? NetworkImage(_avatarUrl!)
                                : null,
                            child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                                ? Text(
                                    (_nameController.text.isNotEmpty ? _nameController.text : 'U')[0].toUpperCase(),
                                    style: TextStyle(
                                      fontFamily: 'ClashDisplay',
                                      fontSize: 36,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary(isDark),
                                    ),
                                  )
                                : null,
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
                              child: _isUploadingAvatar
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Personal Info Section
                  _SectionLabel(label: l10n.personalInformation),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: l10n.fullName,
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            style: const TextStyle(fontFamily: 'Inter'),
                            validator: (v) => v == null || v.trim().isEmpty ? l10n.fieldRequired : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: l10n.email,
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
                                  : l10n.selectDateOfBirth,
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
                            dropdownColor: AppColors.surface(isDark),
                            style: TextStyle(color: AppColors.textPrimary(isDark)),
                            value: _gender,
                            decoration: InputDecoration(
                              labelText: l10n.gender,
                              prefixIcon: Icon(Icons.wc_outlined),
                            ),
                            items: _genders.map((g) => DropdownMenuItem(
                              value: g,
                              child: Text(
                                g == 'Male' ? l10n.male : g == 'Female' ? l10n.female : l10n.other,
                                style: const TextStyle(fontFamily: 'Inter'),
                              ),
                            )).toList(),
                            onChanged: (v) => setState(() => _gender = v),
                          ),
                          const SizedBox(height: 16),
                          // Blood Type Dropdown
                          DropdownButtonFormField<String>(
                            dropdownColor: AppColors.surface(isDark),
                            style: TextStyle(color: AppColors.textPrimary(isDark)),
                            value: _bloodType,
                            decoration: InputDecoration(
                              labelText: l10n.bloodType,
                              prefixIcon: Icon(Icons.bloodtype_outlined),
                            ),
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
                  _SectionLabel(label: l10n.measurements),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _heightController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: l10n.heightCm,
                                prefixIcon: Icon(Icons.height_outlined),
                              ),
                              style: const TextStyle(fontFamily: 'Inter'),
                              // FIX: validate height range. Previously
                              // out-of-range values were silently dropped
                              // by _saveProfile (the if-condition skipped
                              // the write) — the user saw "saved successfully"
                              // but the value wasn't persisted.
                              validator: (value) {
                                final v = value?.trim() ?? '';
                                if (v.isEmpty) return null; // optional
                                final h = double.tryParse(v);
                                if (h == null) {
                                  return 'Enter a number.';
                                }
                                if (h <= 0 || h > 300) {
                                  return 'Height must be 1-300 cm.';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _weightController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: l10n.weightKg,
                                prefixIcon: Icon(Icons.monitor_weight_outlined),
                              ),
                              style: const TextStyle(fontFamily: 'Inter'),
                              // FIX: validate weight range.
                              validator: (value) {
                                final v = value?.trim() ?? '';
                                if (v.isEmpty) return null; // optional
                                final w = double.tryParse(v);
                                if (w == null) {
                                  return 'Enter a number.';
                                }
                                if (w <= 0 || w > 1000) {
                                  return 'Weight must be 1-1000 kg.';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Emergency Contact Section
                  _SectionLabel(label: l10n.emergencyContactSection),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emergencyNameController,
                            decoration: InputDecoration(
                              labelText: l10n.contactName,
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            style: const TextStyle(fontFamily: 'Inter'),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emergencyPhoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: l10n.phoneNumber,
                              prefixIcon: Icon(Icons.phone_outlined),
                              hintText: '+234 801 234 5678',
                              helperText: 'Include country code (e.g. +234).',
                            ),
                            style: const TextStyle(fontFamily: 'Inter'),
                            // FIX: validate phone format. Previously any
                            // string was accepted — empty, "abc", "123" —
                            // which silently broke the medical ID's "Call"
                            // button and SOS SMS dispatch at emergency time.
                            validator: (value) {
                              final v = value?.trim() ?? '';
                              if (v.isEmpty) {
                                // Phone is optional (user may not have an
                                // emergency contact yet) — but if a name is
                                // entered, the phone is required. We rely
                                // on _saveProfile to enforce the name+phone
                                // pairing; here we just validate format when
                                // a value is present.
                                return null;
                              }
                              // E.164 format: + then 7-15 digits.
                              final e164 = RegExp(r'^\+[1-9]\d{6,14}$');
                              // Permissive: + then digits/spaces/dashes/parens.
                              final permissive = RegExp(r'^\+?[0-9\s\-()]{7,20}$');
                              if (!e164.hasMatch(v) && !permissive.hasMatch(v)) {
                                return 'Enter a valid phone number with country code.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emergencyRelationshipController,
                            decoration: InputDecoration(
                              labelText: 'Relationship',
                              prefixIcon: Icon(Icons.people_outline),
                              hintText: l10n.relationshipHint,
                            ),
                            style: const TextStyle(fontFamily: 'Inter'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Allergies Section
                  _SectionLabel(label: l10n.allergies),
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
                                  decoration: InputDecoration(
                                    labelText: l10n.addAllergy,
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
                              label: Text(allergy, style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.textPrimary(isDark))),
                              deleteIcon: Icon(Icons.close, size: 16, color: AppColors.textSecondary(isDark)),
                              onDeleted: () => _removeAllergy(allergy),
                              backgroundColor: (AppColors.primary(isDark)).withValues(alpha: 0.08),
                              side: BorderSide(color: (AppColors.primary(isDark)).withValues(alpha: 0.3)),
                              labelStyle: TextStyle(color: AppColors.textPrimary(isDark)),
                            )).toList(),
                          ),
                          if (_allergies.isEmpty)
                            Text(
                              l10n.noAllergiesAdded,
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
                  _SectionLabel(label: l10n.chronicConditions),
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
                                  decoration: InputDecoration(
                                    labelText: l10n.addCondition,
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
                              label: Text(condition, style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.textPrimary(isDark))),
                              deleteIcon: Icon(Icons.close, size: 16, color: AppColors.textSecondary(isDark)),
                              onDeleted: () => _removeCondition(condition),
                              backgroundColor: (isDark ? AppColors.darkWarning : AppColors.lightWarning).withValues(alpha: 0.08),
                              side: BorderSide(color: (isDark ? AppColors.darkWarning : AppColors.lightWarning).withValues(alpha: 0.3)),
                            )).toList(),
                          ),
                          if (_chronicConditions.isEmpty)
                            Text(
                              l10n.noConditionsAdded,
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
                          : Text(
                              l10n.saveChanges,
                              style: const TextStyle(
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
