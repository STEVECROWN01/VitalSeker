import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/loading_overlay.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // FIX (audit H-17): client-side rate limiting for sign-in attempts.
  // After 5 failed attempts within 60 seconds, the user is locked out
  // for 60 seconds with a countdown. This prevents brute-force attacks
  // and reduces load on the Supabase auth endpoint. Supabase also has
  // server-side rate limiting, but this gives immediate user feedback.
  int _failedAttempts = 0;
  DateTime? _firstFailedAt;
  DateTime? _lockedUntil;

  @override
  void initState() {
    super.initState();
    // FIX: the Sign-In button's enable/disable condition reads
    // `_emailController.text.isEmpty || _passwordController.text.isEmpty`
    // in build(). Without listeners, the button stays disabled after the
    // user types until something else triggers a rebuild (e.g., toggling
    // password visibility). Add listeners that call setState on every
    // keystroke so the button updates in real time.
    _emailController.addListener(_onTextChanged);
    _passwordController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  bool get _isLockedOut {
    if (_lockedUntil == null) return false;
    if (DateTime.now().isAfter(_lockedUntil!)) {
      // Lockout expired — reset.
      _lockedUntil = null;
      _failedAttempts = 0;
      _firstFailedAt = null;
      return false;
    }
    return true;
  }

  int get _lockoutSecondsRemaining {
    if (_lockedUntil == null) return 0;
    return _lockedUntil!.difference(DateTime.now()).inSeconds;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    // FIX (audit H-17): check rate limit before attempting sign-in.
    if (_isLockedOut) {
      _showError(
        'Too many failed attempts. Please wait ${_lockoutSecondsRemaining}s '
        'before trying again.',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // Success — reset the failed attempt counter.
      _failedAttempts = 0;
      _firstFailedAt = null;
      if (mounted) context.go(AppConfig.dashboard);
    } catch (e) {
      // Track failed attempts for rate limiting.
      final wasLockedOut = _failedAttempts >= 4; // _recordFailedAttempt will bump to 5
      _recordFailedAttempt();
      // FIX: if _recordFailedAttempt just triggered a lockout, the
      // lockout snackbar is already showing. Don't overwrite it with
      // the per-attempt error — the lockout message is more actionable.
      if (!wasLockedOut || _failedAttempts < 5) {
        _showError(AuthService.getFriendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Record a failed sign-in attempt and trigger a lockout if the threshold
  /// is reached. FIX (audit H-17).
  void _recordFailedAttempt() {
    final now = DateTime.now();

    // Reset the window if the first failure was more than 60s ago.
    if (_firstFailedAt != null &&
        now.difference(_firstFailedAt!).inSeconds > 60) {
      _failedAttempts = 0;
      _firstFailedAt = null;
    }

    _firstFailedAt ??= now;
    _failedAttempts++;

    // After 5 failed attempts, lock out for 60 seconds.
    if (_failedAttempts >= 5) {
      _lockedUntil = now.add(const Duration(seconds: 60));
      _showError(
        'Too many failed attempts. Account locked for 60 seconds. '
        'Please wait before trying again.',
      );
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

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      final l10n = AppLocalizations.of(context)!;
      _showError(l10n.enterEmailFirst);
      return;
    }

    try {
      final authService = ref.read(authServiceProvider);
      await authService.resetPassword(email);
      if (mounted) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.passwordResetSent(email),
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
    } catch (e) {
      _showError(AuthService.getFriendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return LoadingOverlay(
      isLoading: _isLoading,
      message: l10n.signingIn,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 56),
                  // Logo — VitalSeker brand logo, clean squircle (no gradient container).
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/images/branding/app_logo.png',
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: Text(
                      l10n.welcomeBack,
                      style: AppTextStyles.heading2.copyWith(
                        fontSize: 28,
                        color: AppColors.textPrimary(isDark),
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      l10n.signInSubtitle,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary(isDark),
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                  ),
                  const SizedBox(height: 40),
                  // Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(
                      labelText: l10n.email,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return l10n.emailRequired;
                      // FIX (audit 3.1): use proper email validation matching
                      // register_screen — check for both @ and . in the domain.
                      if (!value.contains('@') || !value.contains('.')) return l10n.enterValidEmail;
                      return null;
                    },
                  ).animate().slideX(duration: 400.ms, delay: 200.ms, begin: 0.1),
                  const SizedBox(height: 16),
                  // Password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _signIn(),
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: l10n.password,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return l10n.passwordRequired;
                      if (value.length < 6) return l10n.passwordMinLength;
                      return null;
                    },
                  ).animate().slideX(duration: 400.ms, delay: 300.ms, begin: 0.1),
                  const SizedBox(height: 8),
                  // Forgot password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _resetPassword,
                      child: Text(
                        l10n.forgotPassword,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.primary(isDark),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Sign In button
                  // FIX (audit 3.3): disable button when email/password are empty.
                  ElevatedButton(
                    onPressed: (_emailController.text.isEmpty || _passwordController.text.isEmpty || _isLoading)
                        ? null
                        : _signIn,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      backgroundColor: AppColors.primary(isDark),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(l10n.signIn, style: AppTextStyles.button.copyWith(fontSize: 16)),
                  ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
                  const SizedBox(height: 24),
                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.divider(isDark))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          l10n.orContinueWith,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.textHint(isDark),
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: AppColors.divider(isDark))),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Social sign in
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SocialButton(
                        icon: Icons.g_mobiledata_rounded,
                        label: l10n.google,
                        onPressed: _signInWithGoogle,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 16),
                      _SocialButton(
                        icon: Icons.apple,
                        label: l10n.apple,
                        onPressed: _signInWithApple,
                        isDark: isDark,
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms, delay: 500.ms),
                  const SizedBox(height: 32),
                  // Register link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.dontHaveAccount,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary(isDark),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go(AppConfig.register),
                        child: Text(
                          l10n.signUp,
                          style: AppTextStyles.subheading2.copyWith(
                            color: AppColors.primary(isDark),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Footer credit
                  Center(
                    child: Text(
                      l10n.poweredBy(AppConfig.producer),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textTertiary(isDark).withValues(alpha: 0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
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

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isDark;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 24),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary(isDark),
        side: BorderSide(color: AppColors.border(isDark)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
