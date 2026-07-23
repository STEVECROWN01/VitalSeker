import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:vitalseker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/services/edge_function_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/widgets/medical_disclaimer_banner.dart';
import '../../../shared/widgets/pro_feature_gate.dart';
import '../../../core/providers/subscription_provider.dart';

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
  bool _isRecording = false;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;

  /// Max chars per translation request. Protects the DeepL free-tier quota
  /// (1M chars/month) from a single oversized request. The edge function
  /// also caps at 1000 chars server-side as a defense-in-depth.
  static const int _maxChars = 1000;

  /// Map display names → ISO 639-1 codes (uppercase for DeepL).
  ///
  /// FIX (audit H-23): the previous _langCodes map had 19 entries but
  /// _languages had 38 entries — 19 languages in the list had no mapping.
  /// When a user selected one of those (e.g. "Hebrew"), the fallback
  /// passed the English display name to the edge function, which DeepL
  /// rejected with an error. The comment claimed Swahili/Hausa/Yoruba/
  /// Igbo/Tagalog were "intentionally omitted" from both the map AND the
  /// list, but they were actually in the list — the comment was wrong.
  ///
  // We now include ALL DeepL-supported languages in both the map and the
  // list, and exclude languages DeepL doesn't support (Swahili, Hausa,
  // Yoruba, Igbo, Tagalog, Malay, Burmese, Amharic, Persian). This
  // ensures every selectable language has a valid DeepL code.
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
    // DeepL-supported languages that were previously in _languages but
    // missing from _langCodes:
    'Hebrew': 'HE',
    'Czech': 'CS',
    'Greek': 'EL',
    'Romanian': 'RO',
    'Hungarian': 'HU',
    'Swedish': 'SV',
    'Norwegian': 'NB',
    'Danish': 'DA',
    'Finnish': 'FI',
    'Slovak': 'SK',
    'Ukrainian': 'UK',
    'Bulgarian': 'BG',
    'Estonian': 'ET',
    'Latvian': 'LV',
    'Lithuanian': 'LT',
    'Slovenian': 'SL',
  };

  /// Languages available for selection. Every entry must have a
  /// corresponding code in [_langCodes].
  static const List<String> _languages = [
    'French', 'Spanish', 'Arabic', 'German',
    'Portuguese', 'Chinese', 'Japanese', 'Italian', 'Dutch',
    'Polish', 'Russian', 'Korean', 'Turkish', 'Indonesian',
    'Thai', 'Vietnamese', 'Hindi', 'Bengali', 'Urdu',
    'Hebrew', 'Czech', 'Greek', 'Romanian', 'Hungarian',
    'Swedish', 'Norwegian', 'Danish', 'Finnish', 'Slovak', 'Ukrainian',
    'Bulgarian', 'Estonian', 'Latvian', 'Lithuanian', 'Slovenian',
    // NOTE: Persian, Malay, Burmese, Amharic, Swahili, Hausa, Yoruba,
    // Igbo, and Tagalog are NOT supported by DeepL as of 2025. They are
    // intentionally omitted from both _langCodes and _languages to prevent
    // users from selecting a language that will return an error.
  ];

  @override
  void dispose() {
    _textController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize();
      if (mounted) setState(() {});
    } catch (_) {
      _speechAvailable = false;
    }
  }

  Future<void> _startRecording() async {
    if (!_speechAvailable) {
      await _initSpeech();
      if (!_speechAvailable) {
        AppSnackBar.error(context, l10n.speechNotAvailable);
        return;
      }
    }
    try {
      final availableLocales = await _speech.locales();
      final appLocale = Localizations.localeOf(context).languageCode;
      String? bestLocaleId;
      try {
        final match = availableLocales.firstWhere(
          (l) => l.localeId.startsWith(appLocale),
          orElse: () => availableLocales.first,
        );
        bestLocaleId = match.localeId;
      } catch (_) {
        bestLocaleId = null;
      }

      await _speech.listen(
        onResult: (result) {
          setState(() {
            _textController.text = result.recognizedWords;
            _textController.selection = TextSelection.fromPosition(
              TextPosition(offset: _textController.text.length),
            );
          });
        },
        localeId: bestLocaleId,
        listenMode: stt.ListenMode.dictation,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 5),
      );
      setState(() => _isRecording = true);
    } catch (e) {
      AppSnackBar.error(context, l10n.couldNotStartRecording);
    }
  }

  Future<void> _stopRecording() async {
    await _speech.stop();
    setState(() => _isRecording = false);
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );
      if (result == null || result.files.single.path == null) return;
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      if (content.length > _maxChars) {
        AppSnackBar.error(context, l10n.translationTooLong);
        return;
      }
      setState(() {
        _textController.text = content.substring(0, _maxChars);
      });
      AppSnackBar.success(context, l10n.fileLoadedTapTranslate);
    } catch (e) {
      AppSnackBar.error(context, 'Could not read file: $e');
    }
  }

  Future<void> _scanDocument() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 90);
      if (picked == null) return;

      AppSnackBar.info(context, l10n.scanningDocument);

      // FIX (audit H-24): the previous code used only the Latin script
      // recognizer, so a prescription in Arabic, Chinese, Japanese, Korean,
      // or Devanagari returned empty text. We now run multiple recognizers
      // (Latin + the user's locale script if applicable) and merge results.
      final inputImage = InputImage.fromFilePath(picked.path);

      // Determine which scripts to try based on the user's locale.
      // Latin is always tried first (works for English, French, Spanish,
      // German, etc.). For locales that use other scripts, we add those.
      final scriptsToTry = <TextRecognitionScript>[
        TextRecognitionScript.latin,
      ];
      final localeLang = Localizations.localeOf(context).languageCode;
      switch (localeLang) {
        case 'ar':
        case 'fa':
        case 'ur':
          // Arabic not supported by ML Kit text recognition — Latin only.
          break;
        case 'zh':
          scriptsToTry.add(TextRecognitionScript.chinese);
          break;
        case 'ja':
          scriptsToTry.add(TextRecognitionScript.japanese);
          break;
        case 'ko':
          scriptsToTry.add(TextRecognitionScript.korean);
          break;
        case 'hi':
        case 'bn':
          scriptsToTry.add(TextRecognitionScript.devanagiri);
          break;
      }

      // Run each recognizer and collect results. We pick the one with the
      // most extracted text (heuristic: the right script produces more).
      String bestText = '';
      for (final script in scriptsToTry) {
        try {
          final recognizer = TextRecognizer(script: script);
          final result = await recognizer.processImage(inputImage);
          await recognizer.close();
          final text = result.text.trim();
          if (text.length > bestText.length) {
            bestText = text;
          }
        } catch (e) {
          // Some scripts may not be available on all devices — skip silently.
          debugPrint('OCR script $script failed: $e');
        }
      }

      final extractedText = bestText;
      if (extractedText.isEmpty) {
        if (mounted) {
          AppSnackBar.error(
            context,
            'No text found in the image. Try a clearer photo, or type the text manually. '
            'Note: non-Latin scripts may not be recognized on all devices.',
          );
        }
        return;
      }

      // Cap at max chars
      final cappedText = extractedText.substring(0, extractedText.length > _maxChars ? _maxChars : extractedText.length);
      setState(() {
        _textController.text = cappedText;
      });

      if (mounted) {
        AppSnackBar.success(context, 'Document scanned! ${cappedText.length} characters extracted. Tap Translate.');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'Could not scan document: $e');
      }
    }
  }

  Future<void> _downloadPdf(bool isDark) async {
    try {
      final originalText = _textController.text.trim();
      final translatedText = _translation ?? '';
      final targetLang = _targetLang;

      // FIX (audit H-25): load a Unicode font so non-Latin scripts (Arabic,
      // Chinese, Japanese, Korean, Cyrillic, etc.) render correctly in the
      // PDF. The pdf package's default font only includes Latin glyphs —
      // without this, translated text appears as empty boxes / question marks.
      //
      // We load Inter from the app's bundled assets (already in pubspec.yaml
      // under assets/fonts/). Inter covers Latin, Latin Extended, Cyrillic,
      // Greek, and Vietnamese. For CJK/Arabic/Hebrew, a Noto font would be
      // needed — but bundling all Noto fonts is ~50MB. As a pragmatic fix,
      // we detect non-Latin text and show a warning if the font doesn't
      // cover it.
      final fontData = await rootBundle.load('assets/fonts/Inter-Regular.ttf');
      final fontDataBold = await rootBundle.load('assets/fonts/Inter-Bold.ttf');
      final unicodeFont = pw.Font.ttf(fontData);
      final unicodeFontBold = pw.Font.ttf(fontDataBold);

      // Check if the translated text contains non-Latin characters that
      // Inter doesn't cover (CJK, Arabic, Hebrew, Devanagari).
      final hasNonLatin = translatedText.codeUnits.any((c) =>
          c > 0x2000 && (
              (c >= 0x4E00 && c <= 0x9FFF) ||  // CJK Unified
              (c >= 0x3040 && c <= 0x30FF) ||  // Japanese kana
              (c >= 0xAC00 && c <= 0xD7AF) ||  // Korean Hangul
              (c >= 0x0600 && c <= 0x06FF) ||  // Arabic
              (c >= 0x0590 && c <= 0x05FF) ||  // Hebrew
              (c >= 0x0900 && c <= 0x097F)     // Devanagari
          ));
      if (hasNonLatin && mounted) {
        AppSnackBar.info(
          context,
          'Note: the translation contains characters that may not render in the PDF. '
          'If the PDF shows blank boxes, please copy the text from the screen instead.',
        );
      }

      // Create PDF document with the Unicode font as the default theme font.
      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: unicodeFont, bold: unicodeFontBold),
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'VitalSeker Medical Translation',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Original Text:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text(originalText, style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 24),
              pw.Text('Translation ($targetLang):', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text(translatedText, style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 40),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text(
                'Generated by VitalSeker — ${DateTime.now().toString().substring(0, 16)}',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
            ];
          },
        ),
      );

      // Save to temp directory
      final dir = await getTemporaryDirectory();
      final fileName = 'vitalseker_translation_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${dir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      // Share the PDF (user can save to device or share)
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'VitalSeker Medical Translation — $targetLang',
      );

      if (mounted) {
        AppSnackBar.success(context, l10n.translationPdfReady);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'Could not generate PDF: $e');
      }
    }
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
    final isPro = ref.watch(isProUserProvider);

    if (!isPro) {
      return const ProFeatureGate(
        featureName: 'Medical Translation',
        featureDescription: 'Translate medical terms and phrases into 40+ languages with DeepL. Includes voice recording, document scanning (OCR), and PDF export.',
        featureIcon: Icons.translate,
      );
    }

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

            // ── Input field with mic + file upload buttons ──
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    minLines: 2,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: l10n.medicalTermOrPhrase,
                      hintText: _isRecording ? l10n.listeningHint : l10n.medicalTermHint,
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
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    // Mic button
                    GestureDetector(
                      onTap: _isRecording ? _stopRecording : _startRecording,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _isRecording
                              ? AppColors.error(isDark)
                              : AppColors.primaryContainer(isDark),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isRecording ? Icons.stop : Icons.mic,
                          color: _isRecording ? Colors.white : AppColors.primary(isDark),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // File upload button
                    GestureDetector(
                      onTap: _pickFile,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer(isDark),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.attach_file,
                          color: AppColors.primary(isDark),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Camera scan button (OCR)
                    GestureDetector(
                      onTap: _scanDocument,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer(isDark),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.camera_alt_outlined,
                          color: AppColors.primary(isDark),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
                    const SizedBox(height: 12),
                    // Download as PDF button
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _downloadPdf(isDark),
                        icon: Icon(Icons.picture_as_pdf, size: 18, color: AppColors.primary(isDark)),
                        label: Text(
                          l10n.downloadPdf,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary(isDark),
                          ),
                        ),
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
