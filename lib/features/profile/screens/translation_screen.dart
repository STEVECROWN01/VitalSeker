import 'package:flutter/material.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/edge_function_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/widgets/medical_disclaimer_banner.dart';

/// Medical Translation Screen
///
/// Lets the user translate a medical term or short phrase into one of several
/// supported target languages by invoking the `translate` Supabase edge
/// function via [EdgeFunctionService.translate].
///
/// Layout:
///   1. Intro caption explaining the feature.
///   2. Multi-line text input for the medical term/phrase.
///   3. Dropdown for the target language (French, Spanish, Arabic, Swahili,
///      German, Portuguese, Chinese, Japanese).
///   4. Primary "Translate" button (shows a spinner while awaiting the edge
///      function).
///   5. Result card with a SelectableText widget (so the user can copy the
///      translation into another app) — or a placeholder card before the
///      first translation runs.
class TranslationScreen extends ConsumerStatefulWidget {
  const TranslationScreen({super.key});

  @override
  ConsumerState<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends ConsumerState<TranslationScreen> {
  final TextEditingController _textController = TextEditingController();
  String _targetLang = 'French';
  String? _translation;
  bool _isLoading = false;

  /// Max chars per translation request. Protects the DeepL free-tier quota
  /// (1M chars/month) from a single oversized request. The edge function
  /// also caps at 1000 chars server-side as a defense-in-depth.
  static const int _maxChars = 1000;

  /// Map display names → ISO 639-1 codes (uppercase for DeepL).
  /// The previous implementation passed the display name ('French') to the
  /// edge function, which then had to do its own mapping. Sending the ISO
  /// code is more robust and lets the edge function trust the client.
  static const Map<String, String> _langCodes = {
    'French': 'FR',
    'Spanish': 'ES',
    'Arabic': 'AR',
    'German': 'DE',
    'Portuguese': 'PT',
    'Chinese': 'ZH',
    'Japanese': 'JA',
    'Italian': 'IT',
    'Dutch': 'NL',
    'Polish': 'PL',
    'Russian': 'RU',
    'Korean': 'KO',
    'Turkish': 'TR',
    'Indonesian': 'ID',
    'Thai': 'TH',
    'Vietnamese': 'VI',
    'Hindi': 'HI',
    'Bengali': 'BN',
    'Urdu': 'UR',
    // Note: Swahili, Hausa, Yoruba, Igbo, Tagalog are NOT supported by
    // DeepL as of 2025. They're intentionally omitted from this map and
    // from the _languages list below to prevent users from selecting a
    // language that will return an error.
  };

  static const List<String> _languages = [
    'French', 'Spanish', 'Arabic', 'German',
    'Portuguese', 'Chinese', 'Japanese', 'Italian', 'Dutch',
    'Polish', 'Russian', 'Korean', 'Turkish', 'Indonesian',
    'Thai', 'Vietnamese', 'Hindi', 'Bengali', 'Urdu',
  ];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _translate() async {
    final l10n = AppLocalizations.of(context)!;
    final text = _textController.text.trim();
    if (text.isEmpty) {
      AppSnackBar.error(context, l10n.pleaseEnterTermToTranslate);
      return;
    }
    // Enforce client-side character limit to protect DeepL monthly quota.
    // The edge function also caps at 1000 chars server-side.
    if (text.length > _maxChars) {
      AppSnackBar.error(
        context,
        l10n.translationTooLong(_maxChars),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _translation = null;
    });

    try {
      final edgeService = EdgeFunctionService();
      // Pass the ISO 639-1 code (e.g. 'FR') instead of the display name
      // ('French') — more robust and lets the edge function trust the client.
      final isoCode = _langCodes[_targetLang] ?? _targetLang;
      final result = await edgeService.translate(
        text: text,
        targetLang: isoCode,
      );
      if (!mounted) return;
      // Check emptiness BEFORE setState so we don't briefly render an empty
      // result card with a green checkmark.
      if (result.isEmpty) {
        setState(() => _isLoading = false);
        AppSnackBar.error(context, l10n.noTranslationReturned);
        return;
      }
      setState(() {
        _translation = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppSnackBar.errorFromException(
        context,
        l10n.translationFailed,
        e,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.medicalTranslation,
          style: AppTextStyles.heading3.copyWith(color: AppColors.primary(isDark)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.medicalTranslationIntro,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary(isDark),
              ),
            ),
            const SizedBox(height: 20),

            // ── Input field ──
            TextField(
              controller: _textController,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.medicalTermOrPhrase,
                hintText: l10n.medicalTermHint,
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppColors.inputFill(isDark),
              ),
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 16),

            // ── Target language dropdown ──
            DropdownButtonFormField<String>(
              value: _targetLang,
              decoration: InputDecoration(
                labelText: l10n.targetLanguage,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppColors.inputFill(isDark),
              ),
              dropdownColor: AppColors.surface(isDark),
              style: TextStyle(color: AppColors.textPrimary(isDark)),
              items: _languages
                  .map((lang) => DropdownMenuItem(
                        value: lang,
                        child: Text(
                          lang,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary(isDark),
                          ),
                        ),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _targetLang = value);
                }
              },
            ),
            const SizedBox(height: 20),

            // ── Translate button ──
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _translate,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.translate, size: 20),
                label: Text(
                  _isLoading ? l10n.translating : l10n.translate,
                  style: AppTextStyles.button.copyWith(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary(isDark),
                  disabledBackgroundColor:
                      AppColors.primary(isDark).withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Result / placeholder card ──
            if (_translation != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground(isDark),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight(isDark)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle_outline,
                            color: AppColors.primary(isDark), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          l10n.translationTargetLanguage(_targetLang),
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.primary(isDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      _translation!,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textPrimary(isDark),
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              )
            else if (!_isLoading)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.subtleBackground(isDark),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight(isDark)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: AppColors.textHint(isDark), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.translationWillAppear,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary(isDark),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            const MedicalDisclaimerBanner(compact: true),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
