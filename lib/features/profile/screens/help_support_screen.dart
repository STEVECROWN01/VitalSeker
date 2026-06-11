import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/theme/app_colors.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitSupport() async {
    if (_subjectController.text.trim().isEmpty || _messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _isSubmitting = false);
      _subjectController.clear();
      _messageController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Support request sent! We\'ll respond within 24 hours.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FAQ Section
            _SectionLabel(label: 'Frequently Asked Questions'),
            Card(
              child: Column(
                children: [
                  _FaqItem(
                    question: 'How does the AI symptom triage work?',
                    answer: 'Our AI analyzes your reported symptoms against a comprehensive medical database to provide urgency-based recommendations. It categorizes your condition into Low, Medium, High, or Emergency urgency levels and suggests appropriate next steps.',
                  ),
                  _FaqItem(
                    question: 'Is my health data secure?',
                    answer: 'Yes. All data is encrypted end-to-end using AES-256 encryption. We comply with GDPR and HIPAA standards. Your health information is never shared with third parties without your explicit consent.',
                  ),
                  _FaqItem(
                    question: 'How do I share my health passport?',
                    answer: 'Navigate to your Health Passport from the bottom navigation bar. Tap the QR code icon to generate a shareable QR code that healthcare providers can scan to access your critical health information securely.',
                  ),
                  _FaqItem(
                    question: 'Can I add family members?',
                    answer: 'Yes! Pro subscribers can add up to 5 family member profiles, and Enterprise subscribers have unlimited family profiles. Each family member gets their own health passport and triage capabilities.',
                  ),
                  _FaqItem(
                    question: 'How do I cancel my subscription?',
                    answer: 'Go to Profile > Subscription and select the Free plan to downgrade. Your Pro or Enterprise features will remain active until the end of your current billing period.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Contact Support Section
            _SectionLabel(label: 'Contact Support'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _subjectController,
                      decoration: const InputDecoration(
                        labelText: 'Subject',
                        prefixIcon: Icon(Icons.subject_outlined),
                      ),
                      style: const TextStyle(fontFamily: 'Inter'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _messageController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        alignLabelWithHint: true,
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 40),
                          child: Icon(Icons.message_outlined),
                        ),
                      ),
                      style: const TextStyle(fontFamily: 'Inter'),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitSupport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.lightPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Submit',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Email Contact
            _SectionLabel(label: 'Other Ways to Reach Us'),
            Card(
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.lightPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.email_outlined, color: AppColors.lightPrimary, size: 20),
                ),
                title: const Text('Email Us', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500)),
                subtitle: const Text(
                  'support@vitalseker.com',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.lightPrimary),
                ),
                trailing: const Icon(Icons.open_in_new, size: 16),
                onTap: () async {
                  final uri = Uri.parse('mailto:support@vitalseker.com?subject=${Uri.encodeComponent('VitalSeker Support Request')}');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not open email client')),
                      );
                    }
                  }
                },
              ),
            ),
            const SizedBox(height: 32),

            // Version info
            Center(
              child: Column(
                children: [
                  Text(
                    AppConfig.appName,
                    style: TextStyle(
                      fontFamily: 'ClashDisplay',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.grey400 : AppColors.grey500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version ${AppConfig.version}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: isDark ? AppColors.grey500 : AppColors.grey400,
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
}

class _FaqItem extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
      ),
      child: ExpansionTile(
        iconColor: AppColors.lightPrimary,
        collapsedIconColor: isDark ? AppColors.grey400 : AppColors.grey500,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          question,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        children: [
          Text(
            answer,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: isDark ? AppColors.grey300 : AppColors.grey700,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'DMSans',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.grey500 : AppColors.grey400,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
