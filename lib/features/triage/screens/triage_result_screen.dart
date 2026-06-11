import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/urgency_badge.dart';

class TriageResultScreen extends StatelessWidget {
  final Map<String, dynamic> triageData;

  const TriageResultScreen({super.key, required this.triageData});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final triage = triageData['triage'] as Map<String, dynamic>? ?? triageData;
    final urgencyLevel = triage['urgency_level'] as String? ?? 'medium';
    final urgencyScore = triage['urgency_score'] as int? ?? 50;
    final seekCare = triage['seek_care'] as String? ?? 'schedule-appointment';
    final recommendations = (triage['recommendations'] as List<dynamic>? ?? []).cast<String>();
    final redFlags = (triage['red_flags'] as List<dynamic>? ?? []).cast<String>();
    final possibleConditions = triage['possible_conditions'] as List<dynamic>? ?? [];
    final disclaimer = triage['disclaimer'] as String? ?? 'This is not a medical diagnosis. Always consult a healthcare professional.';
    final followUpQuestions = (triage['follow_up_questions'] as List<dynamic>? ?? []).cast<String>();

    return Scaffold(
      appBar: AppBar(title: const Text('Triage Results')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Urgency Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: _urgencyGradient(urgencyLevel),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Icon(
                    _urgencyIcon(urgencyLevel),
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  UrgencyBadge(urgencyLevel: urgencyLevel, fontSize: 14),
                  const SizedBox(height: 12),
                  Text(
                    'Urgency Score: $urgencyScore/100',
                    style: const TextStyle(
                      fontFamily: 'ClashDisplay',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _seekCareLabel(seekCare),
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().scale(duration: 500.ms, curve: Curves.elasticOut, begin: const Offset(0.9, 0.9)),
            const SizedBox(height: 24),

            // Red Flags
            if (redFlags.isNotEmpty) ...[
              _SectionTitle(title: 'Red Flags', icon: Icons.warning_amber_rounded, color: AppColors.urgencyEmergency),
              const SizedBox(height: 8),
              ...redFlags.map((flag) => Card(
                color: AppColors.urgencyEmergency.withValues(alpha: isDark ? 0.1 : 0.05),
                child: ListTile(
                  leading: const Icon(Icons.error_outline, color: AppColors.urgencyEmergency),
                  title: Text(flag, style: const TextStyle(fontFamily: 'Inter', fontSize: 14)),
                ),
              )),
              const SizedBox(height: 24),
            ],

            // Recommendations
            if (recommendations.isNotEmpty) ...[
              _SectionTitle(title: 'Recommendations', icon: Icons.lightbulb_outline, color: AppColors.lightPrimary),
              const SizedBox(height: 8),
              ...recommendations.asMap().entries.map((entry) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.lightPrimary.withValues(alpha: 0.12),
                    child: Text(
                      '${entry.key + 1}',
                      style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.lightPrimary),
                    ),
                  ),
                  title: Text(entry.value, style: const TextStyle(fontFamily: 'Inter', fontSize: 14)),
                ),
              )),
              const SizedBox(height: 24),
            ],

            // Possible Conditions
            if (possibleConditions.isNotEmpty) ...[
              _SectionTitle(title: 'Possible Conditions', icon: Icons.medical_information_outlined, color: AppColors.lightSecondary),
              const SizedBox(height: 8),
              ...possibleConditions.map((condition) {
                final c = condition as Map<String, dynamic>;
                return Card(
                  child: ListTile(
                    leading: Icon(
                      c['probability'] == 'high' ? Icons.circle : (c['probability'] == 'medium' ? Icons.remove_circle_outline : Icons.circle_outlined),
                      color: c['probability'] == 'high' ? AppColors.urgencyHigh : (c['probability'] == 'medium' ? AppColors.urgencyMedium : AppColors.urgencyLow),
                    ),
                    title: Text(c['name'] ?? '', style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: Text(c['description'] ?? '', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? AppColors.grey400 : AppColors.grey500)),
                  ),
                );
              }),
              const SizedBox(height: 24),
            ],

            // Follow-up Questions
            if (followUpQuestions.isNotEmpty) ...[
              _SectionTitle(title: 'Follow-up Questions', icon: Icons.help_outline, color: AppColors.lightInfo),
              const SizedBox(height: 8),
              ...followUpQuestions.map((q) => Card(
                child: ListTile(
                  leading: const Icon(Icons.chat_bubble_outline, color: AppColors.lightInfo, size: 20),
                  title: Text(q, style: const TextStyle(fontFamily: 'Inter', fontSize: 14)),
                ),
              )),
              const SizedBox(height: 24),
            ],

            // Disclaimer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.urgencyMedium.withValues(alpha: isDark ? 0.1 : 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.urgencyMedium.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.urgencyMedium, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      disclaimer,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: isDark ? AppColors.grey400 : AppColors.grey500,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  LinearGradient _urgencyGradient(String level) {
    switch (level) {
      case 'low': return const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)]);
      case 'medium': return const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFFFB74D)]);
      case 'high': return const LinearGradient(colors: [Color(0xFFFF5722), Color(0xFFFF7043)]);
      case 'emergency': return const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFEF5350)]);
      default: return const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFFFB74D)]);
    }
  }

  IconData _urgencyIcon(String level) {
    switch (level) {
      case 'low': return Icons.check_circle_rounded;
      case 'medium': return Icons.warning_rounded;
      case 'high': return Icons.error_rounded;
      case 'emergency': return Icons.emergency_rounded;
      default: return Icons.info_rounded;
    }
  }

  String _seekCareLabel(String care) {
    switch (care) {
      case 'self-care': return 'Self-Care Recommended';
      case 'schedule-appointment': return 'Schedule an Appointment';
      case 'urgent-care': return 'Visit Urgent Care';
      case 'emergency': return 'Seek Emergency Care';
      default: return 'Consult a Healthcare Provider';
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionTitle({required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'ClashDisplay',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
