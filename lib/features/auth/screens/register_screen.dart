import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/loading_overlay.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  // Persistent controller for the DOB field — previously a new controller was
  // created on every build (controller: TextEditingController(text: ...))
  // which leaked the previous one and broke focus/state.
  final _dobController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;

  // New optional fields
  DateTime? _dateOfBirth;
  String? _gender;
  String? _bloodType;

  static const List<String> _genderOptions = ['Male', 'Female', 'Other'];
  static const List<String> _bloodTypeOptions = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  ];

  /// Maps the internal gender value (stored as English: "Male"/"Female"/"Other")
  /// to its localized display label. The stored value stays English so existing
  /// profile data keeps parsing across language switches.
  String _genderLabel(String gender, AppLocalizations l10n) {
    switch (gender) {
      case 'Male':
        return l10n.male;
      case 'Female':
        return l10n.female;
      case 'Other':
        return l10n.other;
      default:
        return gender;
    }
  }

  @override
  void initState() {
    super.initState();
    _dobController.addListener(() {
      // Keep controller text in sync with _dateOfBirth when it changes externally.
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error(isDark),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success(isDark),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final l10n = AppLocalizations.of(context)!;
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: l10n.selectDateOfBirth,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary(Theme.of(context).brightness == Brightness.dark),
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateOfBirth = picked;
        _dobController.text =
            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms) {
      final l10n = AppLocalizations.of(context)!;
      _showError(l10n.acceptTermsRequired);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final response = await authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
      );

      if (mounted) {
        // Check if email confirmation is required
        final session = response.session;
        final user = response.user;
        final needsConfirmation = session == null ||
            (user != null && user.confirmationSentAt != null);

        if (needsConfirmation) {
          final l10n = AppLocalizations.of(context)!;
          _showSuccess(l10n.accountCreatedVerifyEmail);
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) context.go(AppConfig.login);
        } else {
          // Auto-confirmed: persist optional profile fields (DOB/gender/blood type).
          // The auth.users row was just created and the handle_new_user trigger
          // provisions a public.users row, so we can update it now.
          if (user != null) {
            final updateData = <String, dynamic>{};
            if (_dateOfBirth != null) {
              updateData['date_of_birth'] =
                  _dateOfBirth!.toIso8601String().split('T')[0];
            }
            if (_gender != null) updateData['gender'] = _gender;
            if (_bloodType != null) updateData['blood_type'] = _bloodType;
            if (updateData.isNotEmpty) {
              try {
                final db = ref.read(databaseServiceProvider);
                await db.updateUserProfile(user.id, updateData);
                // Refresh cached profile so onboarding/dashboard see the new values.
                ref.invalidate(userProfileProvider);
              } catch (e) {
                // Non-fatal: profile can be edited later. Log for debugging.
                debugPrint('Failed to persist optional profile fields: $e');
              }
            }
          }
          context.go(AppConfig.dashboard);
        }
      }
    } catch (e) {
      _showError(AuthService.getFriendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithGoogle();
      if (mounted) context.go(AppConfig.dashboard);
    } catch (e) {
      _showError(AuthService.getFriendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithApple();
      if (mounted) context.go(AppConfig.dashboard);
    } catch (e) {
      _showError(AuthService.getFriendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return LoadingOverlay(
      isLoading: _isLoading,
      message: l10n.creatingAccount,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  // Back button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => context.pop(),
                      icon: Icon(
                        Icons.arrow_back_ios_new,
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.createAccount,
                    style: TextStyle(
                      fontFamily: 'ClashDisplay',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.joinVitalSeker,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Full Name
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n.fullName,
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return l10n.nameRequired;
                      if (value.trim().length < 2) return l10n.nameMinChars;
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n.email,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return l10n.emailRequired;
                      if (!value.contains('@') || !value.contains('.')) return l10n.enterValidEmailAddress;
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n.password,
                      hintText: l10n.atLeast6Chars,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return l10n.passwordRequired;
                      if (value.length < 6) return l10n.passwordMinLength;
                      if (!value.contains(RegExp(r'[A-Z]'))) return l10n.includeUppercase;
                      if (!value.contains(RegExp(r'[0-9]'))) return l10n.includeNumber;
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Confirm Password
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _signUp(),
                    decoration: InputDecoration(
                      labelText: l10n.confirmPassword,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return l10n.confirmPasswordRequired;
                      if (value != _passwordController.text) return l10n.passwordsDoNotMatch;
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // ── Optional Fields Section ──
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.primary(isDark),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.optionalDetails,
                        style: TextStyle(
                          fontFamily: 'ClashDisplay',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(isDark),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: AppColors.divider(isDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Date of Birth
                  GestureDetector(
                    onTap: _pickDateOfBirth,
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: _dobController,
                        decoration: InputDecoration(
                          labelText: l10n.dateOfBirth,
                          prefixIcon: const Icon(Icons.cake_outlined),
                          suffixIcon: Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                            color: AppColors.textSecondary(isDark),
                          ),
                          hintText: l10n.selectDateOfBirthHint,
                        ),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          color: _dateOfBirth != null
                              ? AppColors.textPrimary(isDark)
                              : AppColors.textHint(isDark),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Gender Dropdown
                  DropdownButtonFormField<String>(
                    value: _gender,
                    decoration: InputDecoration(
                      labelText: l10n.gender,
                      prefixIcon: const Icon(Icons.wc_outlined),
                      hintText: l10n.selectGender,
                    ),
                    items: _genderOptions.map((gender) {
                      return DropdownMenuItem<String>(
                        value: gender,
                        child: Text(
                          _genderLabel(gender, l10n),
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 16),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _gender = value),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Blood Type Dropdown
                  DropdownButtonFormField<String>(
                    value: _bloodType,
                    decoration: InputDecoration(
                      labelText: l10n.bloodType,
                      prefixIcon: const Icon(Icons.bloodtype_outlined),
                      hintText: l10n.selectBloodType,
                    ),
                    items: _bloodTypeOptions.map((type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(
                          type,
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 16),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _bloodType = value),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Terms checkbox
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Checkbox(
                          value: _acceptTerms,
                          onChanged: (value) => setState(() => _acceptTerms = value ?? false),
                          activeColor: AppColors.primary(isDark),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _acceptTerms = !_acceptTerms),
                          child: Text.rich(
                            TextSpan(
                              text: l10n.iAgreeTo,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: AppColors.textSecondary(isDark),
                              ),
                              children: [
                                TextSpan(
                                  text: l10n.termsOfService,
                                  style: TextStyle(
                                    color: AppColors.primary(isDark),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextSpan(text: l10n.andText),
                                TextSpan(
                                  text: l10n.privacyPolicy,
                                  style: TextStyle(
                                    color: AppColors.primary(isDark),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Create Account button
                  ElevatedButton(
                    onPressed: _signUp,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(l10n.createAccount),
                  ),
                  const SizedBox(height: 24),
                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.divider(isDark))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          l10n.orContinueWith,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: AppColors.textHint(isDark),
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: AppColors.divider(isDark))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Google Sign Up
                  OutlinedButton.icon(
                    onPressed: _signInWithGoogle,
                    icon: Icon(Icons.g_mobiledata_rounded, size: 24, color: AppColors.textPrimary(isDark)),
                    label: Text(
                      l10n.continueWithGoogle,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.border(isDark)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(double.infinity, 52),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Apple Sign Up
                  OutlinedButton.icon(
                    onPressed: _signInWithApple,
                    icon: Icon(Icons.apple, size: 24, color: AppColors.textPrimary(isDark)),
                    label: Text(
                      l10n.continueWithApple,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.border(isDark)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(double.infinity, 52),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Login link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.alreadyHaveAccount,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: AppColors.textSecondary(isDark),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go(AppConfig.login),
                        child: Text(
                          l10n.signIn,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary(isDark),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
