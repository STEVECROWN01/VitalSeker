import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_snack_bar.dart';

class HelpSupportScreen extends ConsumerStatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  ConsumerState<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends ConsumerState<HelpSupportScreen> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  /// Index of the currently-expanded FAQ item, or `null` if none are open.
  ///
  /// Per Bug 4: opening one FAQ should automatically close the others. The
  /// previous implementation used independent [ExpansionTile] widgets each
  /// with their own internal expansion state, so multiple items could be
  /// open at once. We now drive the expansion from this single field and
  /// rebuild the list with [initiallyExpanded] set on only the matching
  /// index — opening item N sets _expandedFaqIndex = N, which collapses any
  /// previously-open item on the next rebuild.
  int? _expandedFaqIndex;

  /// Static FAQ content. Kept as a top-level constant so the build method
  /// can iterate with `.asMap().entries` and feed each entry's index into
  /// the controlled [_FaqItem] below.
  static const List<({String question, String answer})> _faqItems = [
    (
      question: 'How does the AI symptom triage work?',
      answer:
          'Our AI analyzes your reported symptoms against a comprehensive medical database to provide urgency-based recommendations. It categorizes your condition into Low, Medium, High, or Emergency urgency levels and suggests appropriate next steps.',
    ),
    (
      question: 'Is my health data secure?',
      answer:
          'Yes. All data is encrypted end-to-end using AES-256 encryption. We comply with GDPR and HIPAA standards. Your health information is never shared with third parties without your explicit consent.',
    ),
    (
      question: 'How do I share my health passport?',
      answer:
          'Navigate to your Health Passport from the bottom navigation bar. Tap the QR code icon to generate a shareable QR code that healthcare providers can scan to access your critical health information securely.',
    ),
    (
      question: 'Can I add family members?',
      answer:
          'Yes! Pro subscribers can add up to 5 family member profiles, and Enterprise subscribers have unlimited family profiles. Each family member gets their own health passport and triage capabilities.',
    ),
    (
      question: 'How do I cancel my subscription?',
      answer:
          'Go to Profile > Subscription and select the Free plan to downgrade. Your Pro or Enterprise features will remain active until the end of your current billing period.',
    ),
  ];

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  /// Infer a priority hint from keywords in the subject + message so urgent
  /// requests can bubble to the top of the support queue. This is purely a
  /// heuristic — the support team can override it.
  String _inferPriority(String subject, String message) {
    final combined = '${subject.toLowerCase()} ${message.toLowerCase()}';
    if (combined.contains('emergency') ||
        combined.contains('urgent') ||
        combined.contains('cannot access') ||
        combined.contains('data loss')) {
      return 'urgent';
    }
    if (combined.contains('bug') ||
        combined.contains('crash') ||
        combined.contains('broken') ||
        combined.contains('not working')) {
      return 'high';
    }
    if (combined.contains('question') ||
        combined.contains('how do i') ||
        combined.contains('help')) {
      return 'normal';
    }
    return 'low';
  }

  Future<void> _submitSupport() async {
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();
    if (subject.isEmpty || message.isEmpty) {
      AppSnackBar.error(context, 'Please fill in both subject and message.');
      return;
    }
    if (subject.length < 5) {
      AppSnackBar.error(context, 'Subject must be at least 5 characters.');
      return;
    }
    if (message.length < 10) {
      AppSnackBar.error(context, 'Message must be at least 10 characters.');
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) {
      AppSnackBar.error(context, 'You must be signed in to submit a support request.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final db = ref.read(databaseServiceProvider);
      final priority = _inferPriority(subject, message);
      // ── Persist the ticket to the support_tickets table ──
      // This is the canonical "submit" — once this call returns successfully,
      // the request is in the queue and the success snackbar below is the
      // ONLY feedback shown. The "Could not open email client …" message is
      // intentionally NOT in this code path (per Bug 3) — it lives only in
      // the "Email Us" ListTile.onTap below so a form submission can never
      // surface an email-client error.
      await db.insertSupportTicket(
        userId: user.id,
        subject: subject,
        message: message,
        priority: priority,
      );
      if (mounted) {
        _subjectController.clear();
        _messageController.clear();
        AppSnackBar.success(
          context,
          priority == 'urgent'
              ? 'Urgent request received! Our team will prioritize this.'
              : 'Support request sent! We\'ll respond within 24 hours.',
        );
      }
    } catch (e) {
      // The DB insert failed — show the failure message (not the email
      // client message). The "email support@vitalseker.com" hint is part of
      // the failure copy as a fallback contact channel, but we never invoke
      // the email launcher here.
      if (mounted) {
        AppSnackBar.errorFromException(
          context,
          'Failed to submit support request. Please try again or email support@vitalseker.com.',
          e,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
                  // Build the FAQ items from the static list. Each item is
                  // a controlled [_FaqItem]: passing `isExpanded` based on
                  // whether its index matches `_expandedFaqIndex`, and an
                  // `onToggle` callback that flips the field. Opening item
                  // N collapses any other open item because only one index
                  // can match `_expandedFaqIndex` at a time.
                  //
                  // We pass a `ValueKey` that combines the item index with
                  // its `isExpanded` state. ExpansionTile is uncontrolled —
                  // `initiallyExpanded` is only read on first build — so
                  // when the parent's `_expandedFaqIndex` flips, the key
                  // changes for the affected items and Flutter recreates
                  // them with the new `initiallyExpanded` value. (Items
                  // that stay collapsed keep their key and aren't rebuilt,
                  // which is correct because their visual state is also
                  // unchanged.)
                  for (final entry in _faqItems.asMap().entries)
                    _FaqItem(
                      key: ValueKey(
                        'faq-${entry.key}-${_expandedFaqIndex == entry.key}',
                      ),
                      question: entry.value.question,
                      answer: entry.value.answer,
                      isExpanded: _expandedFaqIndex == entry.key,
                      onToggle: () {
                        setState(() {
                          // Tapping the currently-open item closes it;
                          // tapping a collapsed item opens it (and the
                          // previously-open one will collapse on rebuild).
                          _expandedFaqIndex =
                              _expandedFaqIndex == entry.key
                                  ? null
                                  : entry.key;
                        });
                      },
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
                      textInputAction: TextInputAction.next,
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
                      textInputAction: TextInputAction.newline,
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
                    const SizedBox(height: 8),
                    // Hint that the form actually persists.
                    Row(
                      children: [
                        Icon(Icons.lock_outline, size: 12, color: AppColors.textHint(isDark)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Your request is saved to your account and visible to our support team. We respond within 24 hours.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: AppColors.textHint(isDark),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitSupport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary(isDark),
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
                    color: (AppColors.primary(isDark)).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.email_outlined, color: AppColors.primary(isDark), size: 20),
                ),
                title: const Text('Email Us', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500)),
                subtitle: Text(
                  'support@vitalseker.com',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.primary(isDark)),
                ),
                trailing: const Icon(Icons.open_in_new, size: 16),
                onTap: () async {
                  final uri = Uri.parse('mailto:support@vitalseker.com?subject=${Uri.encodeComponent('VitalSeker Support Request')}');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  } else {
                    if (context.mounted) {
                      AppSnackBar.info(context, 'Could not open email client. Please email support@vitalseker.com manually.');
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
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version ${AppConfig.version}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.textHint(isDark),
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

  /// Whether this item is currently expanded. Driven from the parent's
  /// `_expandedFaqIndex` field (single source of truth) so opening one
  /// item automatically closes any other open item.
  final bool isExpanded;

  /// Tap callback that toggles the parent's expansion state for this item.
  final VoidCallback onToggle;

  const _FaqItem({
    super.key,
    required this.question,
    required this.answer,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
      ),
      child: ExpansionTile(
        // ── Controlled expansion (per Bug 4) ──
        // `initiallyExpanded` only sets the initial state on first build —
        // for ongoing control we'd need a different approach. But because
        // the parent rebuilds with a fresh `isExpanded` value whenever
        // _expandedFaqIndex changes, and because ExpansionTile reads
        // `initiallyExpanded` on every rebuild (it's a key in the internal
        // state restoration), tapping another item will collapse this one.
        //
        // We also wire `onExpansionChanged` to the parent's `onToggle` so
        // tapping this tile's header flips `_expandedFaqIndex` — that
        // triggers a rebuild which collapses any sibling tile whose
        // `isExpanded` is now false.
        initiallyExpanded: isExpanded,
        onExpansionChanged: (_) => onToggle(),
        iconColor: AppColors.primary(isDark),
        collapsedIconColor: AppColors.textSecondary(isDark),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          question,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary(isDark),
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
          color: AppColors.textHint(isDark),
          letterSpacing: 1,
        ),
      ),
    );
  }
}
