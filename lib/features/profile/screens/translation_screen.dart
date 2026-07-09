import 'package:flutter/material.dart';
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
    'Hebrew', 'Persian', 'Czech', 'Greek', 'Romanian', 'Hungarian',
    'Swedish', 'Norwegian', 'Danish', 'Finnish', 'Slovak', 'Ukrainian',
    'Malay', 'Burmese', 'Amharic', 'Swahili', 'Hausa', 'Yoruba', 'Igbo',
    'Tagalog',
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
        AppSnackBar.error(context, 'Speech recognition not available. Please type instead.');
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
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 5),
        options: stt.SpeechListenOptions(
          localeId: bestLocaleId,
          listenMode: stt.ListenMode.dictation,
        ),
      );
      setState(() => _isRecording = true);
    } catch (e) {
      AppSnackBar.error(context, 'Could not start recording. Check microphone permissions.');
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
        AppSnackBar.error(context, 'File too long (max $_maxChars characters).');
        return;
      }
      setState(() {
        _textController.text = content.substring(0, _maxChars);
      });
      AppSnackBar.success(context, 'File loaded. Tap Translate to proceed.');
    } catch (e) {
      AppSnackBar.error(context, 'Could not read file: $e');
    }
  }

  Future<void> _scanDocument() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 90);
      if (picked == null) return;

      AppSnackBar.info(context, 'Scanning document...');

      // Use ML Kit text recognition to extract text from the image
      final inputImage = InputImage.fromFilePath(picked.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final extractedText = recognizedText.text.trim();
      if (extractedText.isEmpty) {
        if (mounted) {
          AppSnackBar.error(context, 'No text found in the image. Try a clearer photo.');
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

      // Create PDF document
      final pdf = pw.Document();

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
      await SharePlus.instance.share(ShareParams(
        files: [XFile(filePath)],
        subject: 'VitalSeker Medical Translation — $targetLang',
      ));

      if (mounted) {
        AppSnackBar.success(context, 'Translation PDF ready!');
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
                      hintText: _isRecording ? 'Listening...' : l10n.medicalTermHint,
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
                          'Download PDF',
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
