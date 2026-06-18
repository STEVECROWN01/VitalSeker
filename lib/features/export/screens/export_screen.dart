import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../../core/config/app_config.dart';
import '../../../core/providers/health_passport_provider.dart';
import '../../../core/services/edge_function_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_snack_bar.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  bool _includeHistory = true;
  bool _isExporting = false;

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);
    try {
      final passport = ref.read(healthPassportProvider).valueOrNull;
      final edgeService = EdgeFunctionService();
      
      final pdfData = await edgeService.exportPdf(
        passportId: passport?.id,
        includeHistory: _includeHistory,
      );

      // Generate PDF locally
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (context) => pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 10),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'VitalSeker Health Passport',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  'Crafted under ${AppConfig.producer} design guidance.',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                ),
              ],
            ),
          ),
          build: (context) => [
            pw.Header(level: 0, text: 'Patient Information'),
            pw.Paragraph(text: 'Name: ${pdfData['patient']?['name'] ?? 'N/A'}'),
            pw.Paragraph(text: 'Email: ${pdfData['patient']?['email'] ?? 'N/A'}'),
            pw.Paragraph(text: 'Date of Birth: ${pdfData['patient']?['date_of_birth'] ?? 'N/A'}'),
            pw.Paragraph(text: 'Blood Type: ${pdfData['patient']?['blood_type'] ?? 'N/A'}'),
            
            if (pdfData['health_passport'] != null) ...[
              pw.Header(level: 0, text: 'Health Passport'),
              pw.Paragraph(text: 'Vital Score: ${pdfData['health_passport']['vital_score'] ?? 'N/A'}/100'),
              pw.Paragraph(text: 'Blood Type: ${pdfData['health_passport']['blood_type'] ?? 'N/A'}'),
              pw.Paragraph(text: 'Allergies: ${(pdfData['health_passport']['allergies'] as List?)?.join(', ') ?? 'None'}'),
              pw.Paragraph(text: 'Medications: ${(pdfData['health_passport']['medications'] as List?)?.join(', ') ?? 'None'}'),
              pw.Paragraph(text: 'Chronic Conditions: ${(pdfData['health_passport']['chronic_conditions'] as List?)?.join(', ') ?? 'None'}'),
            ],
            
            if (_includeHistory && (pdfData['symptom_history'] as List?)?.isNotEmpty == true) ...[
              pw.Header(level: 0, text: 'Symptom History'),
              ...(pdfData['symptom_history'] as List).map((log) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('${log['date'] ?? 'Unknown date'}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Symptoms: ${(log['symptoms'] as List?)?.join(', ') ?? 'N/A'}'),
                    pw.Text('Severity: ${log['severity'] ?? 'N/A'}/10'),
                  ],
                ),
              )),
            ],
            
            pw.Divider(),
            pw.Paragraph(
              text: pdfData['footer']?['disclaimer'] ?? 'This document does not constitute a medical diagnosis.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Paragraph(
              text: pdfData['footer']?['producer'] ?? 'Crafted under ${AppConfig.producer} design guidance.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
          ],
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/vitalseker_health_passport.pdf');
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'VitalSeker Health Passport',
          text: 'My VitalSeker Health Passport - Generated by ${AppConfig.producer}',
        );
      }
    } catch (e) {
      if (mounted) AppSnackBar.errorFromException(context, 'Failed to export PDF. Please try again.', e);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Export Health Data')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                children: [
                  Icon(Icons.picture_as_pdf, color: Colors.white, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'Export Health Passport',
                    style: TextStyle(
                      fontFamily: 'ClashDisplay',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Generate a PDF with your health data',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Options
            Text(
              'Export Options',
              style: TextStyle(
                fontFamily: 'ClashDisplay',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: SwitchListTile(
                title: const Text('Include Symptom History'),
                subtitle: Text(
                  'Add your recent symptom logs to the PDF',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
                value: _includeHistory,
                onChanged: (value) => setState(() => _includeHistory = value),
                activeColor: AppColors.primary(isDark),
              ),
            ),
            const SizedBox(height: 32),

            // Export Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isExporting ? null : _exportPdf,
                icon: _isExporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.download),
                label: Text(_isExporting ? 'Exporting...' : 'Export & Share PDF'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'PDF includes ${AppConfig.producer} credit as producer',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: AppColors.textHint(isDark),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
