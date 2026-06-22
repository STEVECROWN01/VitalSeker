import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/theme/app_colors.dart';

/// Terms of Service screen.
///
/// Static legal copy. The "Last updated" date is derived from the app version
/// so it stays in sync with releases without manual edits.
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.termsOfService)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary(isDark).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary(isDark).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary(isDark).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.description_outlined,
                      color: AppColors.primary(isDark),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.termsOfServiceTitle(AppConfig.appName),
                          style: TextStyle(
                            fontFamily: 'ClashDisplay',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(isDark),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.lastUpdatedVersion(AppConfig.version),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: AppColors.textSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _Section(
              number: '1',
              title: l10n.tosSection1Title,
              isDark: isDark,
              children: [
                _Para(
                  l10n.tosSection1Para1(AppConfig.appName),
                  isDark: isDark,
                ),
                _Para(
                  l10n.tosSection1Para2(AppConfig.producer),
                  isDark: isDark,
                ),
              ],
            ),

            _Section(
              number: '2',
              title: l10n.tosSection2Title,
              isDark: isDark,
              children: [
                _Para(
                  l10n.tosSection2Para1,
                  isDark: isDark,
                ),
                _Para(
                  l10n.tosSection2Para2,
                  isDark: isDark,
                ),
              ],
            ),

            _Section(
              number: '3',
              title: l10n.tosSection3Title,
              isDark: isDark,
              children: [
                _Para(
                  l10n.tosSection3Para1(AppConfig.appName),
                  isDark: isDark,
                ),
                _Para(
                  l10n.tosSection3Para2,
                  isDark: isDark,
                ),
                _Para(
                  l10n.tosSection3Para3,
                  isDark: isDark,
                ),
              ],
            ),

            _Section(
              number: '4',
              title: l10n.tosSection4Title,
              isDark: isDark,
              children: [
                _Para(l10n.tosSection4Intro, isDark: isDark, bold: true),
                _Bullet(l10n.tosSection4Bullet1, isDark: isDark),
                _Bullet(l10n.tosSection4Bullet2, isDark: isDark),
                _Bullet(l10n.tosSection4Bullet3, isDark: isDark),
                _Bullet(l10n.tosSection4Bullet4, isDark: isDark),
                _Bullet(l10n.tosSection4Bullet5, isDark: isDark),
              ],
            ),

            _Section(
              number: '5',
              title: l10n.tosSection5Title,
              isDark: isDark,
              children: [
                _Para(
                  l10n.tosSection5Para1,
                  isDark: isDark,
                ),
                _Para(
                  l10n.tosSection5Para2,
                  isDark: isDark,
                ),
                _Para(
                  l10n.tosSection5Para3,
                  isDark: isDark,
                ),
              ],
            ),

            _Section(
              number: '6',
              title: l10n.tosSection6Title,
              isDark: isDark,
              children: [
                _Para(
                  l10n.tosSection6Para1,
                  isDark: isDark,
                ),
                _Para(
                  l10n.tosSection6Para2,
                  isDark: isDark,
                ),
              ],
            ),

            _Section(
              number: '7',
              title: l10n.tosSection7Title,
              isDark: isDark,
              children: [
                _Para(
                  l10n.tosSection7Para1,
                  isDark: isDark,
                ),
                _Para(
                  l10n.tosSection7Para2,
                  isDark: isDark,
                ),
              ],
            ),

            _Section(
              number: '8',
              title: l10n.tosSection8Title,
              isDark: isDark,
              children: [
                _Para(
                  l10n.tosSection8Para1(AppConfig.producer),
                  isDark: isDark,
                ),
              ],
            ),

            _Section(
              number: '9',
              title: l10n.tosSection9Title,
              isDark: isDark,
              children: [
                _Para(
                  l10n.tosSection9Para1,
                  isDark: isDark,
                ),
                _Para(
                  l10n.tosSection9Para2,
                  isDark: isDark,
                ),
              ],
            ),

            _Section(
              number: '10',
              title: l10n.tosSection10Title,
              isDark: isDark,
              children: [
                _Para(
                  l10n.tosSection10Para1,
                  isDark: isDark,
                ),
              ],
            ),

            _Section(
              number: '11',
              title: l10n.tosSection11Title,
              isDark: isDark,
              children: [
                _Para(
                  l10n.tosSection11Para1,
                  isDark: isDark,
                ),
              ],
            ),

            const SizedBox(height: 24),
            Divider(color: AppColors.divider(isDark)),
            const SizedBox(height: 12),
            Text(
              l10n.tosCopyright(DateTime.now().year, AppConfig.producer, AppConfig.version),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: AppColors.textHint(isDark),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String number;
  final String title;
  final bool isDark;
  final List<Widget> children;

  const _Section({
    required this.number,
    required this.title,
    required this.isDark,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary(isDark).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    number,
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary(isDark),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'ClashDisplay',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _Para extends StatelessWidget {
  final String text;
  final bool isDark;
  final bool bold;

  const _Para(this.text, {required this.isDark, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          height: 1.6,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          color: AppColors.textSecondary(isDark),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  final bool isDark;

  const _Bullet(this.text, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              height: 1.6,
              color: AppColors.primary(isDark),
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                height: 1.6,
                color: AppColors.textSecondary(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
