# ============================================================
# VitalSeker ProGuard Rules
# ============================================================

# ─── ML Kit Text Recognition ─────────────────────────────────
# The google_mlkit_text_recognition plugin references Chinese,
# Devanagari, Japanese, and Korean text recognizer classes that
# are only loaded at runtime if the user selects those scripts.
# R8 can't find them at build time, so we suppress the warnings.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ─── General ML Kit ──────────────────────────────────────────
# Suppress any other ML Kit warnings
-dontwarn com.google.mlkit.**

# ─── Flutter / Dart ──────────────────────────────────────────
# Keep Flutter engine classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ─── Sentry ──────────────────────────────────────────────────
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**

# ─── PostHog ─────────────────────────────────────────────────
-keep class com.posthog.** { *; }
-dontwarn com.posthog.**

# ─── RevenueCat (purchases_flutter) ──────────────────────────
-keep class com.revenuecat.** { *; }
-dontwarn com.revenuecat.**
