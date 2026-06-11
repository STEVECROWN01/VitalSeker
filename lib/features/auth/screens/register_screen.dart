import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/auth_provider.dart';
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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
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
        backgroundColor: AppColors.lightError,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
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
        backgroundColor: AppColors.lightSuccess,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Select Date of Birth',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.lightPrimary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms) {
      _showError('Please accept the Terms of Service and Privacy Policy to continue.');
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
        // When mailer_autoconfirm is off, the session is null until email is verified
        final session = response.session;
        final user = response.user;
        final needsConfirmation = session == null ||
            (user != null && user.confirmationSentAt != null);

        if (needsConfirmation) {
          _showSuccess('Account created! Please check your email to verify your account.');
          // Navigate to login after a short delay
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) context.go(AppConfig.login);
        } else {
          // Auto-confirmed, go to dashboard
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

    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Creating account...',
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
                        color: isDark ? Colors.white : AppColors.lightOnBackground,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create Account',
                    style: TextStyle(
                      fontFamily: 'ClashDisplay',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.lightOnBackground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Join VitalSeker and take control of your health',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: isDark ? AppColors.grey400 : AppColors.grey500,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Full Name
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Name is required';
                      if (value.trim().length < 2) return 'Name must be at least 2 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Email is required';
                      if (!value.contains('@') || !value.contains('.')) return 'Enter a valid email address';
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
                      labelText: 'Password',
                      hintText: 'At least 6 characters',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Password is required';
                      if (value.length < 6) return 'Password must be at least 6 characters';
                      if (!value.contains(RegExp(r'[A-Z]'))) return 'Include at least one uppercase letter';
                      if (!value.contains(RegExp(r'[0-9]'))) return 'Include at least one number';
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
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please confirm your password';
                      if (value != _passwordController.text) return 'Passwords do not match';
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
                          color: AppColors.lightPrimary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Optional Details',
                        style: TextStyle(
                          fontFamily: 'ClashDisplay',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.lightOnBackground,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: isDark ? AppColors.grey700 : AppColors.grey200,
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
                        decoration: InputDecoration(
                          labelText: 'Date of Birth',
                          prefixIcon: const Icon(Icons.cake_outlined),
                          suffixIcon: Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                            color: isDark ? AppColors.grey400 : AppColors.grey500,
                          ),
                          hintText: 'Select your date of birth',
                        ),
                        controller: TextEditingController(
                          text: _dateOfBirth != null
                              ? '${_dateOfBirth!.day.toString().padLeft(2, '0')}/${_dateOfBirth!.month.toString().padLeft(2, '0')}/${_dateOfBirth!.year}'
                              : '',
                        ),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          color: _dateOfBirth != null
                              ? (isDark ? Colors.white : AppColors.lightOnBackground)
                              : (isDark ? AppColors.grey500 : AppColors.grey400),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Gender Dropdown
                  DropdownButtonFormField<String>(
                    value: _gender,
                    decoration: const InputDecoration(
                      labelText: 'Gender',
                      prefixIcon: Icon(Icons.wc_outlined),
                      hintText: 'Select gender',
                    ),
                    items: _genderOptions.map((gender) {
                      return DropdownMenuItem<String>(
                        value: gender,
                        child: Text(
                          gender,
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 16),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _gender = value),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      color: isDark ? Colors.white : AppColors.lightOnBackground,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Blood Type Dropdown
                  DropdownButtonFormField<String>(
                    value: _bloodType,
                    decoration: const InputDecoration(
                      labelText: 'Blood Type',
                      prefixIcon: Icon(Icons.bloodtype_outlined),
                      hintText: 'Select blood type',
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
                      color: isDark ? Colors.white : AppColors.lightOnBackground,
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
                          activeColor: AppColors.lightPrimary,
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _acceptTerms = !_acceptTerms),
                          child: Text.rich(
                            TextSpan(
                              text: 'I agree to the ',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: isDark ? AppColors.grey400 : AppColors.grey500,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Terms of Service',
                                  style: TextStyle(
                                    color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const TextSpan(text: ' and '),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: TextStyle(
                                    color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
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
                    child: const Text('Create Account'),
                  ),
                  const SizedBox(height: 24),
                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: isDark ? AppColors.grey700 : AppColors.grey200)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'or continue with',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: isDark ? AppColors.grey500 : AppColors.grey400,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: isDark ? AppColors.grey700 : AppColors.grey200)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Google Sign Up
                  OutlinedButton.icon(
                    onPressed: _signInWithGoogle,
                    icon: Icon(Icons.g_mobiledata_rounded, size: 24, color: isDark ? Colors.white : AppColors.lightOnBackground),
                    label: Text(
                      'Continue with Google',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : AppColors.lightOnBackground,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: isDark ? AppColors.grey700 : AppColors.grey200),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(double.infinity, 52),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Apple Sign Up
                  OutlinedButton.icon(
                    onPressed: _signInWithApple,
                    icon: Icon(Icons.apple, size: 24, color: isDark ? Colors.white : AppColors.lightOnBackground),
                    label: Text(
                      'Continue with Apple',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : AppColors.lightOnBackground,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: isDark ? AppColors.grey700 : AppColors.grey200),
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
                        'Already have an account? ',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: isDark ? AppColors.grey400 : AppColors.grey500,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go(AppConfig.login),
                        child: Text(
                          'Sign In',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
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
