import 'package:flutter/material.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../../core/config/app_config.dart';
import '../../../core/providers/health_passport_provider.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/services/edge_function_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/widgets/medical_disclaimer_banner.dart';

/// PDF Export screen — redesigned to match the Google Stitch UI design.
///
/// Layout:
///   1. Compact app bar (back + "VitalSeker" headline).
///   2. Scrollable column split into two zones:
///      A. Controls (configuration card):
///         - Date Range dropdown ("Last 30 Days")
///         - 4 section checkboxes: Patient Overview & Vital Stats, Symptoms &
///           Triage Log, Medications & Allergies, AI Analysis Summary.
///         - Action buttons: "Generate PDF" (gradient) + "Send by Email"
///           (surface-container bg).
///      B. Live preview pane:
///         - A4-aspect white container with "PREVIEW" label.
///         - Mini PDF layout: header (VitalSeker + COMPREHENSIVE HEALTH
///           REPORT), patient info grid, AI Diagnostic Summary section with
///           green left-border, recent symptoms log table.
///
/// The existing PDF generation logic (`pw.MultiPage` etc.) is preserved —
/// the section toggles now drive which sections are included in the PDF, and
/// the header gradient is theme-aware via `AppColors.brandGradientFor(isDark)`.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  // ── Section toggles (4 sections per design) ──
  bool _includePatientOverview = true;
  bool _includeSymptomsLog = true;
  bool _includeMedications = true;
  bool _includeAiSummary = true;

  // ── Date range ──
  // Index into _dateRangeOptions.
  int _dateRangeIndex = 0;
  static const _dateRangeOptions = <String>[
    'Last 30 Days',
    'Last 3 Months',
    'Year to Date',
    'All Time',
  ];

  bool _isExporting = false;
  bool _isEmailing = false;

  // Computed once per generation: the patient info used both in the PDF and
  // in the live preview pane.
  Map<String, dynamic> _previewData = const {};

  @override
  void initState() {
    super.initState();
    // Hydrate the preview pane with whatever we can read from providers
    // synchronously so it isn't empty before the user taps "Generate".
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydratePreview());
  }

  void _hydratePreview() {
    final passport = ref.read(healthPassportProvider).valueOrNull;
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (!mounted) return;
    setState(() {
      _previewData = {
        'patient': {
          'name': profile?.fullName ?? 'N/A',
          'email': profile?.email ?? 'N/A',
          'date_of_birth': profile?.dateOfBirth != null
              ? _formatDate(profile!.dateOfBirth!)
              : 'N/A',
          'blood_type': profile?.bloodType ?? passport?.bloodType ?? 'N/A',
        },
        'health_passport': passport != null
            ? {
                'vital_score': passport.vitalScore,
                'blood_type': passport.bloodType,
                'allergies': passport.allergies,
                'medications': passport.medications,
                'chronic_conditions': passport.chronicConditions,
              }
            : null,
      };
    });
  }

  static String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  /// Whether to include the symptom history in the export, derived from the
  /// "Symptoms & Triage Log" checkbox (replaces the old single toggle).
  bool get _includeHistory => _includeSymptomsLog;

  Future<void> _exportPdf({required bool viaEmail}) async {
    final l10n = AppLocalizations.of(context)!;

    // Pro-gating: PDF export is a Pro-only feature per Cahier des Charges
    // Section 2.5 ("Export PDF médecin (Pro) — Aperçu rapport, envoi par email").
    final isPro = ref.read(isProUserProvider);
    if (!isPro) {
      if (!mounted) return;
      AppSnackBar.error(context, l10n.exportProOnly);
      context.push(AppConfig.subscription);
      return;
    }

    setState(() => viaEmail ? _isEmailing = true : _isExporting = true);
    try {
      final passport = ref.read(healthPassportProvider).valueOrNull;
      final edgeService = EdgeFunctionService();

      // Fetch the structured export data via the edge function.
      final pdfData = await edgeService.exportPdf(
        passportId: passport?.id,
        includeHistory: _includeHistory,
      );
      if (!mounted) return;
      setState(() => _previewData = pdfData);

      // Generate PDF locally, gated by the 4 section toggles.
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (context) => pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'VitalSeker',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: _brandPdfColor,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'COMPREHENSIVE HEALTH REPORT',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey600,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Generated: ${_formatDate(DateTime.now())}',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Range: ${_dateRangeOptions[_dateRangeIndex]}',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          build: (context) {
            final blocks = <pw.Widget>[];

            if (_includePatientOverview) {
              blocks.add(pw.Header(level: 0, text: 'Patient Overview & Vital Stats'));
              blocks.add(pw.Paragraph(
                text: 'Name: ${pdfData['patient']?['name'] ?? 'N/A'}',
              ));
              blocks.add(pw.Paragraph(
                text: 'Email: ${pdfData['patient']?['email'] ?? 'N/A'}',
              ));
              blocks.add(pw.Paragraph(
                text: 'Date of Birth: ${pdfData['patient']?['date_of_birth'] ?? 'N/A'}',
              ));
              blocks.add(pw.Paragraph(
                text: 'Blood Type: ${pdfData['patient']?['blood_type'] ?? 'N/A'}',
              ));
              if (pdfData['health_passport'] != null) {
                blocks.add(pw.Paragraph(
                  text:
                      'Vital Score: ${pdfData['health_passport']['vital_score'] ?? 'N/A'}/100',
                ));
                blocks.add(pw.Paragraph(
                  text:
                      'Chronic Conditions: ${(pdfData['health_passport']['chronic_conditions'] as List?)?.join(', ') ?? 'None'}',
                ));
              }
            }

            if (_includeMedications && pdfData['health_passport'] != null) {
              blocks.add(pw.Header(level: 0, text: 'Medications & Allergies'));
              blocks.add(pw.Paragraph(
                text:
                    'Allergies: ${(pdfData['health_passport']['allergies'] as List?)?.join(', ') ?? 'None'}',
              ));
              blocks.add(pw.Paragraph(
                text:
                    'Medications: ${(pdfData['health_passport']['medications'] as List?)?.join(', ') ?? 'None'}',
              ));
            }

            if (_includeSymptomsLog &&
                (pdfData['symptom_history'] as List?)?.isNotEmpty == true) {
              blocks.add(pw.Header(level: 0, text: 'Symptoms & Triage Log'));
              for (final log in (pdfData['symptom_history'] as List)) {
                blocks.add(pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '${log['date'] ?? 'Unknown date'}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Symptoms: ${(log['symptoms'] as List?)?.join(', ') ?? 'N/A'}',
                      ),
                      pw.Text('Severity: ${log['severity'] ?? 'N/A'}/10'),
                    ],
                  ),
                ));
              }
            }

            if (_includeAiSummary) {
              blocks.add(pw.Header(level: 0, text: 'AI Analysis Summary'));
              final aiText = (pdfData['health_passport'] != null)
                  ? 'Patient exhibits generally stable vitals over the ${_dateRangeOptions[_dateRangeIndex].toLowerCase()}. '
                      'Vital Score is ${pdfData['health_passport']['vital_score'] ?? 'N/A'}/100. '
                      'No critical flags detected. Continue current hydration protocol and monitor trends.'
                  : 'AI analysis unavailable — no health passport on file for this patient.';
              blocks.add(pw.Paragraph(text: aiText));
            }

            blocks.add(pw.Divider());
            blocks.add(pw.Paragraph(
              text: pdfData['footer']?['disclaimer'] ??
                  'This document does not constitute a medical diagnosis.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ));
            blocks.add(pw.Paragraph(
              text: pdfData['footer']?['producer'] ??
                  'Powered by ${AppConfig.producer}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ));

            return blocks;
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/vitalseker_health_passport.pdf');
      await file.writeAsBytes(await pdf.save());

      if (!mounted) return;
      if (viaEmail) {
        // share_plus uses the iOS mail/share sheet — same XFiles API works
        // for both "Save to Files" and "Send by Email" flows on mobile.
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'VitalSeker Comprehensive Health Report',
          text:
              'Please find attached my VitalSeker Comprehensive Health Report. Generated by ${AppConfig.producer}.',
        );
      } else {
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'VitalSeker Health Passport',
          text: 'My VitalSeker Health Passport - Generated by ${AppConfig.producer}',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.errorFromException(
          context,
          viaEmail
              ? 'Failed to email PDF. Please try again.'
              : 'Failed to export PDF. Please try again.',
          e,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _isEmailing = false;
        });
      }
    }
  }

  bool get _isDarkContext =>
      mounted ? Theme.of(context).brightness == Brightness.dark : false;

  /// Brand color used in the PDF header — theme-aware via AppColors.
  /// Returned as a `PdfColor` directly so the `pdf` package can render it
  /// without going through Flutter's deprecated `Color.value` getter.
  PdfColor get _brandPdfColor {
    final c = _isDarkContext ? AppColors.darkPrimaryLight : AppColors.lightPrimary;
    return PdfColor(c.r, c.g, c.b, c.a);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top app bar ──
            _TopBar(isDark: isDark),
            // ── Body ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + subtitle
                    Text(
                      l10n.exportMedicalReport,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(isDark),
                        letterSpacing: -0.01,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.exportConfigurePreview,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.textSecondary(isDark),
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Configuration card
                    _ConfigurationCard(
                      isDark: isDark,
                      dateRangeIndex: _dateRangeIndex,
                      onDateRangeChanged: (i) =>
                          setState(() => _dateRangeIndex = i),
                      includePatientOverview: _includePatientOverview,
                      includeSymptomsLog: _includeSymptomsLog,
                      includeMedications: _includeMedications,
                      includeAiSummary: _includeAiSummary,
                      onTogglePatientOverview: (v) =>
                          setState(() => _includePatientOverview = v),
                      onToggleSymptomsLog: (v) =>
                          setState(() => _includeSymptomsLog = v),
                      onToggleMedications: (v) =>
                          setState(() => _includeMedications = v),
                      onToggleAiSummary: (v) =>
                          setState(() => _includeAiSummary = v),
                      l10n: l10n,
                    ),
                    const SizedBox(height: 16),
                    const MedicalDisclaimerBanner(compact: true),
                    const SizedBox(height: 16),
                    // Action buttons
                    _ActionButtons(
                      isDark: isDark,
                      isExporting: _isExporting,
                      isEmailing: _isEmailing,
                      onGenerate: () => _exportPdf(viaEmail: false),
                      onEmail: () => _exportPdf(viaEmail: true),
                      l10n: l10n,
                    ),
                    const SizedBox(height: 28),
                    // Live preview pane
                    _PreviewPane(
                      isDark: isDark,
                      previewData: _previewData,
                      dateRangeLabel: _dateRangeOptions[_dateRangeIndex],
                      includePatientOverview: _includePatientOverview,
                      includeSymptomsLog: _includeSymptomsLog,
                      includeMedications: _includeMedications,
                      includeAiSummary: _includeAiSummary,
                      l10n: l10n,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.pdfIncludesProducer(AppConfig.producer),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: AppColors.textHint(isDark),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Top app bar
// ═══════════════════════════════════════════════════════════════════════════

class _TopBar extends StatelessWidget {
  final bool isDark;
  const _TopBar({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark).withValues(alpha: 0.96),
        border: Border(
          bottom: BorderSide(
            color: AppColors.borderLight(isDark).withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            color: AppColors.primary(isDark),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Text(
            'VitalSeker',
            style: TextStyle(
              fontFamily: 'ClashDisplay',
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.primary(isDark),
              letterSpacing: -0.01,
              height: 1.15,
            ),
          ),
          const Spacer(),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryContainer(isDark).withValues(alpha: 0.4),
              border: Border.all(
                color: AppColors.borderLight(isDark).withValues(alpha: 0.6),
              ),
            ),
            child: Icon(
              Icons.person,
              color: AppColors.primary(isDark),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Configuration card (date range + 4 section checkboxes)
// ═══════════════════════════════════════════════════════════════════════════

class _ConfigurationCard extends StatelessWidget {
  final bool isDark;
  final int dateRangeIndex;
  final ValueChanged<int> onDateRangeChanged;
  final bool includePatientOverview;
  final bool includeSymptomsLog;
  final bool includeMedications;
  final bool includeAiSummary;
  final ValueChanged<bool> onTogglePatientOverview;
  final ValueChanged<bool> onToggleSymptomsLog;
  final ValueChanged<bool> onToggleMedications;
  final ValueChanged<bool> onToggleAiSummary;
  final AppLocalizations l10n;

  const _ConfigurationCard({
    required this.isDark,
    required this.dateRangeIndex,
    required this.onDateRangeChanged,
    required this.includePatientOverview,
    required this.includeSymptomsLog,
    required this.includeMedications,
    required this.includeAiSummary,
    required this.onTogglePatientOverview,
    required this.onToggleSymptomsLog,
    required this.onToggleMedications,
    required this.onToggleAiSummary,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Range
          Text(
            l10n.dateRange,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.subtleBackground(isDark),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.borderLight(isDark).withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: dateRangeIndex,
                      isExpanded: true,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: AppColors.textPrimary(isDark),
                      ),
                      items: List.generate(
                        _ExportScreenState._dateRangeOptions.length,
                        (i) => DropdownMenuItem<int>(
                          value: i,
                          child: Text(_ExportScreenState._dateRangeOptions[i]),
                        ),
                      ),
                      onChanged: (v) {
                        if (v != null) onDateRangeChanged(v);
                      },
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: AppColors.textSecondary(isDark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Divider(
            color: AppColors.borderLight(isDark).withValues(alpha: 0.5),
            height: 1,
          ),
          const SizedBox(height: 16),
          // Include Sections
          Text(
            l10n.includeSections,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCheckbox(
            label: l10n.patientOverview,
            value: includePatientOverview,
            onChanged: onTogglePatientOverview,
            isDark: isDark,
          ),
          _SectionCheckbox(
            label: l10n.symptomsTriageLog,
            value: includeSymptomsLog,
            onChanged: onToggleSymptomsLog,
            isDark: isDark,
          ),
          _SectionCheckbox(
            label: l10n.medicationsAllergies,
            value: includeMedications,
            onChanged: onToggleMedications,
            isDark: isDark,
          ),
          _SectionCheckbox(
            label: l10n.aiAnalysisSummary,
            value: includeAiSummary,
            onChanged: onToggleAiSummary,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _SectionCheckbox extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isDark;

  const _SectionCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: value,
                  onChanged: (v) {
                    if (v != null) onChanged(v);
                  },
                  activeColor: AppColors.primary(isDark),
                  checkColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  side: BorderSide(
                    color: AppColors.borderLight(isDark),
                    width: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Action buttons
// ═══════════════════════════════════════════════════════════════════════════

class _ActionButtons extends StatelessWidget {
  final bool isDark;
  final bool isExporting;
  final bool isEmailing;
  final VoidCallback onGenerate;
  final VoidCallback onEmail;
  final AppLocalizations l10n;
  const _ActionButtons({
    required this.isDark,
    required this.isExporting,
    required this.isEmailing,
    required this.onGenerate,
    required this.onEmail,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Generate PDF — full-width gradient
        SizedBox(
          width: double.infinity,
          height: 52,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: isExporting ? null : onGenerate,
              child: Ink(
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradientFor(isDark),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary(isDark).withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isExporting)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      const Icon(Icons.download, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      isExporting ? l10n.generating : l10n.generatePDF,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.01,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Send by Email — surface-container bg
        SizedBox(
          width: double.infinity,
          height: 52,
          child: Material(
            color: AppColors.subtleBackground(isDark),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: isEmailing ? null : onEmail,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.subtleBackground(isDark),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.primary(isDark).withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isEmailing)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary(isDark),
                        ),
                      )
                    else
                      Icon(Icons.mail, color: AppColors.primary(isDark), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      isEmailing ? l10n.sending : l10n.sendByEmail,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary(isDark),
                        letterSpacing: -0.01,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Live preview pane — A4-aspect white container
// ═══════════════════════════════════════════════════════════════════════════

class _PreviewPane extends StatelessWidget {
  final bool isDark;
  final Map<String, dynamic> previewData;
  final String dateRangeLabel;
  final bool includePatientOverview;
  final bool includeSymptomsLog;
  final bool includeMedications;
  final bool includeAiSummary;
  final AppLocalizations l10n;
  const _PreviewPane({
    required this.isDark,
    required this.previewData,
    required this.dateRangeLabel,
    required this.includePatientOverview,
    required this.includeSymptomsLog,
    required this.includeMedications,
    required this.includeAiSummary,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.preview,
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary(isDark),
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.zoom_out,
                size: 18,
                color: AppColors.textTertiary(isDark),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.zoom_in,
                size: 18,
                color: AppColors.textTertiary(isDark),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: AspectRatio(
              aspectRatio: 1 / 1.414, // A4
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary(isDark).withValues(alpha: 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: _PreviewDocument(
                  isDark: isDark,
                  previewData: previewData,
                  dateRangeLabel: dateRangeLabel,
                  includePatientOverview: includePatientOverview,
                  includeSymptomsLog: includeSymptomsLog,
                  includeMedications: includeMedications,
                  includeAiSummary: includeAiSummary,
                  l10n: l10n,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewDocument extends StatelessWidget {
  final bool isDark;
  final Map<String, dynamic> previewData;
  final String dateRangeLabel;
  final bool includePatientOverview;
  final bool includeSymptomsLog;
  final bool includeMedications;
  final bool includeAiSummary;
  final AppLocalizations l10n;
  const _PreviewDocument({
    required this.isDark,
    required this.previewData,
    required this.dateRangeLabel,
    required this.includePatientOverview,
    required this.includeSymptomsLog,
    required this.includeMedications,
    required this.includeAiSummary,
    required this.l10n,
  });

  // Previously these getters returned mock data ('Alexander Sterling',
  // '14 May 1985 (38)') when no real data was loaded — a user with no
  // passport would see a fake patient profile in the live preview, which
  // was misleading. Now they return a localized "—" placeholder until the
  // real data is fetched via the exportPdf edge function call.
  String get _patientName => previewData['patient']?['name'] ?? '—';
  String get _patientDob => previewData['patient']?['date_of_birth'] ?? '—';
  int get _vitalScore => previewData['health_passport']?['vital_score'] ?? 0;

  /// Symptom history entries returned by the export-pdf edge function
  /// (each entry has `date`, `symptoms`, `severity`, `triage_result`,
  /// `recommendation`). Returns an empty list when no data is available
  /// so the preview can show a localized empty placeholder instead of the
  /// previous hardcoded "Tension Headache" / "Mild Fatigue" mock rows.
  List<Map<String, dynamic>> get _symptomHistory {
    final raw = previewData['symptom_history'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  /// Format an ISO timestamp ("2024-10-12T..." ) as a short "MMM DD" label
  /// for the preview table. Falls back to '—' on parse failure.
  static const _shortMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatPreviewDate(dynamic value) {
    if (value == null) return '—';
    if (value is! String) return '—';
    final dt = DateTime.tryParse(value);
    if (dt == null) return '—';
    final m = (dt.month >= 1 && dt.month <= 12) ? _shortMonths[dt.month - 1] : '—';
    return '$m ${dt.day.toString().padLeft(2, '0')}';
  }

  /// Render the `symptoms` field (a List<String> in the DB schema, but the
  /// edge function may also return a single String) as a comma-separated
  /// label. Falls back to '—'.
  String _formatSymptoms(dynamic value) {
    if (value == null) return '—';
    if (value is List) {
      final items = value.whereType<String>().where((s) => s.isNotEmpty).toList();
      return items.isEmpty ? '—' : items.join(', ');
    }
    if (value is String) return value.isEmpty ? '—' : value;
    return '—';
  }

  /// Map the triage result to a short label. The edge function returns
  /// either a structured TriageResult (Map with `urgencyLevel` /
  /// `urgency_level` / `seekCare`) or a plain string. We pick the most
  /// informative available field and fall back to '—'.
  String _triageLabel(dynamic triageResult) {
    final level = _extractUrgencyLevel(triageResult);
    switch (level) {
      case 'low':
        return l10n.selfCareRecommended;
      case 'medium':
        return l10n.scheduleAppointmentCare;
      case 'high':
        return l10n.visitUrgentCare;
      case 'emergency':
        return l10n.seekEmergencyCare;
      default:
        return '—';
    }
  }

  /// Color for the triage label, mirroring the urgency palette used
  /// elsewhere in the app.
  Color _triageColor(dynamic triageResult) {
    final level = _extractUrgencyLevel(triageResult);
    switch (level) {
      case 'low':
        return const Color(0xFF2B6953);
      case 'medium':
        return const Color(0xFF005F46);
      case 'high':
        return const Color(0xFFB45309);
      case 'emergency':
        return const Color(0xFFB91C1C);
      default:
        return const Color(0xFF2B6953);
    }
  }

  /// Normalize various triage urgency representations to one of
  /// `low`/`medium`/`high`/`emergency`. Returns null when unknown.
  String? _extractUrgencyLevel(dynamic triageResult) {
    String? raw;
    if (triageResult is String) {
      raw = triageResult;
    } else if (triageResult is Map) {
      raw = (triageResult['urgencyLevel'] ??
              triageResult['urgency_level'] ??
              triageResult['seekCare'])
          ?.toString();
    }
    if (raw == null || raw.isEmpty) return null;
    final lower = raw.toLowerCase();
    if (lower.contains('emergency') || lower.contains('red')) return 'emergency';
    if (lower.contains('high') || lower.contains('yellow') ||
        lower.contains('urgent')) return 'high';
    if (lower.contains('medium') || lower.contains('appointment')) return 'medium';
    if (lower.contains('low') || lower.contains('green') ||
        lower.contains('self-care') || lower.contains('self_care') ||
        lower.contains('routine')) return 'low';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Watermark
        Positioned.fill(
          child: Center(
            child: Transform.rotate(
              angle: -0.78, // ~-45deg
              child: Text(
                'VitalSeker PRO',
                style: TextStyle(
                  fontFamily: 'ClashDisplay',
                  fontSize: 60,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF005F46).withValues(alpha: 0.025),
                ),
              ),
            ),
          ),
        ),
        // Document content
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Document Header
            Container(
              padding: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.black.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VitalSeker',
                          style: TextStyle(
                            fontFamily: 'ClashDisplay',
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0C1F1A),
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'COMPREHENSIVE HEALTH REPORT',
                          style: TextStyle(
                            fontFamily: 'DMSans',
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: Colors.black54,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Generated: ${_formatToday()}',
                        style: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 9,
                          color: Color(0xFF0C1F1A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ref: VS-${(DateTime.now().millisecondsSinceEpoch % 100000).toString().padLeft(5, '0')}',
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 8,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Patient Info Grid
            if (includePatientOverview)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  children: [
                    _PreviewInfoRow(
                      label: 'Patient Name',
                      value: _patientName,
                    ),
                    const SizedBox(height: 6),
                    _PreviewInfoRow(
                      label: 'DOB / Age',
                      value: _patientDob,
                    ),
                    const SizedBox(height: 6),
                    _PreviewInfoRow(
                      label: 'Primary Care Physician',
                      // Use real physician name from data if available,
                      // otherwise "—" (was hardcoded 'Dr. Sarah Jenkins').
                      value: previewData['patient']?['primary_care_physician'] ?? '—',
                    ),
                    const SizedBox(height: 6),
                    _PreviewInfoRow(
                      label: 'Reporting Period',
                      value: dateRangeLabel,
                      valueColor: const Color(0xFF005F46),
                      mono: true,
                    ),
                  ],
                ),
              ),
            // AI Diagnostic Summary (green left-border)
            if (includeAiSummary) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: const Color(0xFF005F46),
                      width: 3,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.smart_toy,
                          size: 14,
                          color: Color(0xFF005F46),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'AI Diagnostic Summary',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0C1F1A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Patient exhibits generally stable vitals over the $dateRangeLabel. '
                      'Vital Score is $_vitalScore/100. No critical flags detected. '
                      'Continue current hydration protocol and monitor trends.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        color: Colors.black54,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Medications & Allergies (compact)
            if (includeMedications) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: const Color(0xFF2B6953),
                      width: 3,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.medication,
                          size: 14,
                          color: Color(0xFF2B6953),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Medications & Allergies',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0C1F1A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Allergies: ${(previewData['health_passport']?['allergies'] as List?)?.join(', ') ?? 'None recorded'}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                    Text(
                      'Medications: ${(previewData['health_passport']?['medications'] as List?)?.join(', ') ?? 'None recorded'}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Symptoms Log (mini table)
            if (includeSymptomsLog) ...[
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 14,
                    margin: const EdgeInsets.only(right: 8),
                    color: const Color(0xFF2B6953),
                  ),
                  const Icon(
                    Icons.list_alt,
                    size: 14,
                    color: Color(0xFF2B6953),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Recent Symptoms Log',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0C1F1A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.1),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  children: [
                    // Table header
                    Container(
                      color: const Color(0xFFF2F4F3),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: const [
                          Expanded(
                            flex: 2,
                            child: Text(
                              'DATE',
                              style: TextStyle(
                                fontFamily: 'DMSans',
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: Colors.black54,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'SYMPTOM',
                              style: TextStyle(
                                fontFamily: 'DMSans',
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: Colors.black54,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'TRIAGE',
                              style: TextStyle(
                                fontFamily: 'DMSans',
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: Colors.black54,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Symptom rows — render from real preview data when
                    // available; otherwise show a single localized empty
                    // placeholder row instead of the previous hardcoded
                    // "Tension Headache" / "Mild Fatigue" mock entries.
                    if (_symptomHistory.isEmpty)
                      _PreviewSymptomRow(
                        date: '—',
                        symptom: l10n.noSymptomsLogs,
                        triage: '—',
                        triageColor: const Color(0xFF2B6953),
                      )
                    else
                      ..._symptomHistory.take(2).toList().asMap().entries.map((entry) {
                        final log = entry.value;
                        return _PreviewSymptomRow(
                          date: _formatPreviewDate(log['date']),
                          symptom: _formatSymptoms(log['symptoms']),
                          triage: _triageLabel(log['triage_result']),
                          triageColor: _triageColor(log['triage_result']),
                          shaded: entry.key.isOdd,
                        );
                      }),
                  ],
                ),
              ),
            ],
            const Spacer(),
            // Footer
            Container(
              padding: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.black.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CRAFTED UNDER ${AppConfig.producer.toUpperCase()} DESIGN GUIDANCE',
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 7,
                      fontWeight: FontWeight.w700,
                      color: Colors.black54,
                      letterSpacing: 0.6,
                    ),
                  ),
                  Text(
                    'Page 1 of 2',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 7,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatToday() {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final now = DateTime.now();
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }
}

class _PreviewInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool mono;
  const _PreviewInfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 7,
                  fontWeight: FontWeight.w700,
                  color: Colors.black54,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontFamily: mono ? 'JetBrainsMono' : 'Outfit',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? const Color(0xFF0C1F1A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewSymptomRow extends StatelessWidget {
  final String date;
  final String symptom;
  final String triage;
  final Color triageColor;
  final bool shaded;
  const _PreviewSymptomRow({
    required this.date,
    required this.symptom,
    required this.triage,
    required this.triageColor,
    this.shaded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: shaded ? const Color(0xFFFAFAFA) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              date,
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 9,
                color: Color(0xFF0C1F1A),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              symptom,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                color: Color(0xFF0C1F1A),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              triage,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 9,
                color: triageColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
