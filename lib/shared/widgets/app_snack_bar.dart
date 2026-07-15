import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../theme/app_colors.dart';

/// Friendly, consistent snack-bar helpers.
///
/// Raw exception strings (`$e`) leaked into user-facing snackbars across the
/// app — these helpers sanitize that surface. Each method keeps the same
/// visual style (floating, rounded, icon-led) used by the auth screens so
/// the whole app feels cohesive.
class AppSnackBar {
  AppSnackBar._();

  static void error(BuildContext context, String message) {
    if (!context.mounted) return;
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

  static void success(BuildContext context, String message) {
    if (!context.mounted) return;
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

  static void info(BuildContext context, String message) {
    if (!context.mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary(isDark),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Logs the raw exception and shows a friendly error snackbar.
  /// Use this in catch blocks where you have no specific friendly message.
  //
  // FIX (audit L-16): use Sentry.captureException in addition to debugPrint
  // so errors are captured in release mode (debugPrint is a no-op in
  // release). The debugPrint is kept for dev-mode console visibility.
  static void errorFromException(BuildContext context, String friendlyMessage, Object error) {
    debugPrint('[AppSnackBar] $friendlyMessage — raw: $error');
    // Forward to Sentry if it's initialized. Fire-and-forget — don't block
    // the UI on error reporting.
    try {
      Sentry.captureException(error);
    } catch (_) {
      // Sentry not initialized — ignore.
    }
    // Inline the error snackbar to avoid calling error() which would
    // cause infinite recursion since error() is defined above.
    if (!context.mounted) return;
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
                friendlyMessage,
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
}
