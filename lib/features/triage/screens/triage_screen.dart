import 'package:flutter/material.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/providers/symptom_log_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/services/edge_function_service.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/widgets/medical_disclaimer_banner.dart';
import 'ai_thinking_screen.dart';

/// Structured 5-question triage flow per Cahier des Charges Section 4:
/// "Triage — Question 1" + "Triage — Questions 2–5"
///
/// Flow:
///   Step 1: Symptom selection (multi-select chips) + severity slider 1-10
///   Step 2: Duration (chips: today / 1-3 days / 4-7 days / 1-2 weeks / >2 weeks)
///   Step 3: Age + biological sex (affects triage logic)
///   Step 4: Known conditions + current medications (pre-filled from passport)
///   Step 5: Additional notes (free text) + review → "Analyze with AI"
///
/// Total: 5 questions in 90 seconds (per spec target).
class TriageScreen extends ConsumerStatefulWidget {
  const TriageScreen({super.key});

  @override
  ConsumerState<TriageScreen> createState() => _TriageScreenState();
}

class _TriageScreenState extends ConsumerState<TriageScreen> {
  int _currentStep = 0;
  static const int _totalSteps = 5;

  // Step 1: Symptoms + severity
  final Set<String> _selectedSymptoms = {};
  int _severity = 5; // 1-10

  // Step 2: Duration
  String? _duration;

  // Step 3: Age + sex
  final _ageController = TextEditingController();
  String? _biologicalSex;

  // Step 4: Conditions + medications
  final _conditionsController = TextEditingController();
  final _medicationsController = TextEditingController();

  // Step 5: Notes
  final _notesController = TextEditingController();

  bool _isProcessing = false;

  // Common symptoms for Step 1 (matches Stitch design)
  static const _commonSymptoms = [
    'fever', 'headache', 'cough', 'shortness_of_breath', 'fatigue',
    'dizziness', 'nausea', 'chills', 'muscle_ache', 'insomnia',
    'chest_pain', 'abdominal_pain', 'sore_throat', 'runny_nose',
    'vomiting', 'diarrhea', 'rash', 'joint_pain',
  ];

  static const _durationOptions = [
    'today', '1_to_3_days', '4_to_7_days', '1_to_2_weeks', 'more_than_2_weeks',
  ];

  @override
  void initState() {
    super.initState();
    // Pre-fill Step 4 (conditions/medications) from the user's passport once
    // the profile resolves.
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillFromProfile());
  }

  void _prefillFromProfile() {
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile != null) {
      if (profile.chronicConditions.isNotEmpty) {
        _conditionsController.text = profile.chronicConditions.join(', ');
      }
      // Pre-fill age from DOB if available
      if (profile.dateOfBirth != null) {
        final now = DateTime.now();
        int age = now.year - profile.dateOfBirth!.year;
        if (now.month < profile.dateOfBirth!.month ||
            (now.month == profile.dateOfBirth!.month && now.day < profile.dateOfBirth!.day)) {
          age--;
        }
        if (age > 0) _ageController.text = age.toString();
      }
      // FIX (audit H-31): the profile stores gender as 'Male'/'Female'/'Other'
      // (capitalized — see register_screen.dart _genderOptions). Step 3's sex
      // selector uses lowercase ['male', 'female', 'other']. The comparison
      // _biologicalSex == sex never matched the capitalized stored value, so
      // the sex buttons never appeared pre-selected and the user had to
      // re-select every time. Normalize to lowercase here.
      if (profile.gender != null) {
        _biologicalSex = profile.gender!.toLowerCase();
      }
    }
  }

  @override
  void dispose() {
    _ageController.dispose();
    _conditionsController.dispose();
    _medicationsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _isStepValid {
    switch (_currentStep) {
      case 0:
        return _selectedSymptoms.isNotEmpty;
      case 1:
        return _duration != null;
      case 2:
        return _ageController.text.isNotEmpty && _biologicalSex != null;
      case 3:
        return true; // Conditions/medications are optional
      case 4:
        return true; // Notes are optional
      default:
        return false;
    }
  }

  void _nextStep() {
    if (!_isStepValid) return;
    // Unfocus current field to dismiss keyboard before switching steps.
    FocusScope.of(context).unfocus();
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    } else {
      _runTriage();
    }
  }

  void _previousStep() {
    // Unfocus current field to dismiss keyboard before switching steps.
    FocusScope.of(context).unfocus();
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _runTriage() async {
    final l10n = AppLocalizations.of(context)!;

    // Set _isProcessing immediately to prevent double-taps during the
    // async Pro check + free-tier limit check.
    setState(() => _isProcessing = true);

    try {
    // ── Pro gate ────────────────────────────────────────────────────────
    // FIX: the previous code allowed non-Pro users to run triage (with a
    // 3/month limit), but the edge function returns 403 for non-Pro users
    // BEFORE inserting a symptom_log row. So the quota never incremented,
    // the user filled the entire 5-step form, watched the AI animation,
    // then got a generic "triage failed" error — with no indication that
    // the feature is Pro-only. Worse, the failed request was queued for
    // offline retry, which would keep failing 403 forever.
    //
    // Now: check Pro status BEFORE showing the AI thinking overlay. If
    // not Pro, route to the subscription screen with a clear message.
    // The 3/month free-tier logic is removed — it was unenforceable
    // server-side and contradicted the edge function's hard Pro gate.
    final isPro = await ref.read(isProUserAsyncProvider.future);
    if (!isPro) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      AppSnackBar.error(context, l10n.triageProOnly);
      context.push(AppConfig.proPlan);
      return;
    }

    // Capture the NavigatorState BEFORE the await so we can pop the overlay
    // even if the widget is disposed during the AI call.
    // FIX (audit C-22): the previous code checked `if (!mounted) return;`
    // BEFORE calling Navigator.of(context).pop() — if the widget disposed
    // during the await, the overlay was never popped and the user was
    // stranded on the "AI Thinking" screen forever. By capturing the
    // navigator up front, we can pop the overlay regardless of the
    // parent widget's mounted state (the overlay is a separate route).
    final navigator = Navigator.of(context);

    // Show the AI thinking overlay
    navigator.push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, _, __) => const AiThinkingScreen(),
      ),
    );

    try {
      final edgeService = EdgeFunctionService();
      // Build comprehensive notes including age, sex, conditions, medications
      // so the AI has full context (previously these were collected but discarded)
      final comprehensiveNotes = <String>[
        if (_notesController.text.trim().isNotEmpty) _notesController.text.trim(),
        if (_ageController.text.isNotEmpty) 'Age: ${_ageController.text}',
        if (_biologicalSex != null) 'Biological sex: $_biologicalSex',
        if (_conditionsController.text.trim().isNotEmpty) 'Chronic conditions: ${_conditionsController.text.trim()}',
        if (_medicationsController.text.trim().isNotEmpty) 'Current medications: ${_medicationsController.text.trim()}',
      ].join('. ');

      final result = await edgeService.runTriage(
        symptoms: _selectedSymptoms.toList(),
        severity: _severity,
        duration: _duration,
        notes: comprehensiveNotes.isEmpty ? null : comprehensiveNotes,
        language: ref.read(localeProvider).languageCode,
      );

      // Pop the overlay using the captured navigator — works even if the
      // parent widget has been disposed (the overlay is its own route).
      navigator.pop();

      if (!mounted) return;
      final triage = result['triage'] as Map<String, dynamic>? ?? result;
      context.push(AppConfig.triageResult, extra: triage);
    } catch (e) {
      // Pop the overlay FIRST using the captured navigator so the user
      // never gets stranded, then handle the error.
      navigator.pop();

      if (!mounted) return;

      // Check if this is a 403 (Pro required) — don't queue for retry
      // since it will keep failing. The Pro gate check above should
      // prevent this, but defense-in-depth.
      final errorStr = e.toString();
      final isProRequired = errorStr.contains('403') ||
          errorStr.toLowerCase().contains('pro_required');

      if (!isProRequired) {
        // ── Offline queue (per Cahier des Charges Section 2.3: "Mode Hors-Ligne")
        // Only queue if this is a network error, NOT a 403 Pro-gate rejection
        // (which would keep failing forever).
        final comprehensiveNotes = <String>[
          if (_notesController.text.trim().isNotEmpty) _notesController.text.trim(),
          if (_ageController.text.isNotEmpty) 'Age: ${_ageController.text}',
          if (_biologicalSex != null) 'Biological sex: $_biologicalSex',
          if (_conditionsController.text.trim().isNotEmpty) 'Chronic conditions: ${_conditionsController.text.trim()}',
          if (_medicationsController.text.trim().isNotEmpty) 'Current medications: ${_medicationsController.text.trim()}',
        ].join('. ');

        await OfflineCacheService().queueTriageRequest(
          symptoms: _selectedSymptoms.toList(),
          severity: _severity,
          duration: _duration,
          notes: comprehensiveNotes.isEmpty ? null : comprehensiveNotes,
        );
      }

      AppSnackBar.error(
        context,
        isProRequired ? l10n.triageProOnly : l10n.triageFailed,
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
    } catch (e) {
      debugPrint('[Triage] _runTriage outer error: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        AppSnackBar.error(context, l10n.triageFailed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep > 0) {
              _previousStep();
            } else {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                context.go(AppConfig.dashboard);
              }
            }
          },
        ),
        title: Text('AI Triage', style: AppTextStyles.heading4),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: _buildProgressBar(isDark),
        ),
      ),
      body: Column(
        children: [
          // Step label
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.triageStepOf(_currentStep + 1, _totalSteps),
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
                if (_currentStep > 0)
                  TextButton(
                    onPressed: _previousStep,
                    child: Text(l10n.back),
                  ),
              ],
            ),
          ),
          // Step content + disclaimer (scrollable together, not sticky)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildStepContent(isDark, l10n),
                  const SizedBox(height: 16),
                  const MedicalDisclaimerBanner(compact: true),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          // Bottom navigation
          _buildBottomBar(isDark, l10n),
        ],
      ),
    );
  }

  Widget _buildProgressBar(bool isDark) {
    return LinearProgressIndicator(
      value: (_currentStep + 1) / _totalSteps,
      minHeight: 6,
      backgroundColor: AppColors.outlineVariant(isDark),
      valueColor: AlwaysStoppedAnimation(AppColors.primary(isDark)),
    );
  }

  Widget _buildStepContent(bool isDark, AppLocalizations l10n) {
    switch (_currentStep) {
      case 0:
        return _buildStep1Symptoms(isDark, l10n);
      case 1:
        return _buildStep2Duration(isDark, l10n);
      case 2:
        return _buildStep3AgeSex(isDark, l10n);
      case 3:
        return _buildStep4Conditions(isDark, l10n);
      case 4:
        return _buildStep5Notes(isDark, l10n);
      default:
        return const SizedBox.shrink();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Step 1: Symptom selection + severity slider
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildStep1Symptoms(bool isDark, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI Chat option — user can choose between 5-step triage or chat
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppColors.brandGradientFor(isDark),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/branding/seker_ai_avatar.png',
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.chatWithSeker,
                      style: const TextStyle(
                        fontFamily: 'ClashDisplay',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      l10n.chatWithSekerDesc,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => context.push(AppConfig.aiChat),
                icon: const Icon(Icons.arrow_forward, color: Colors.white),
                tooltip: l10n.chatWithSeker,
              ),
            ],
          ),
        ),
        Text(l10n.triageQ1Title, style: AppTextStyles.heading2.copyWith(
          color: AppColors.textPrimary(isDark),
        )),
        const SizedBox(height: 8),
        Text(l10n.triageQ1Subtitle, style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary(isDark),
        )),
        const SizedBox(height: 24),
        // Symptom chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _commonSymptoms.map((symptom) {
            final isSelected = _selectedSymptoms.contains(symptom);
            final label = _symptomLabel(symptom, l10n);
            return FilterChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedSymptoms.add(symptom);
                  } else {
                    _selectedSymptoms.remove(symptom);
                  }
                });
              },
              selectedColor: AppColors.primary(isDark),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary(isDark),
                fontFamily: 'DMSans',
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: AppColors.inputFill(isDark),
              side: BorderSide(
                color: isSelected ? AppColors.primary(isDark) : AppColors.outlineVariant(isDark),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            );
          }).toList(),
        ),
        const SizedBox(height: 32),
        // Severity slider
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardBackground(isDark),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.triageSeverityLabel, style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.textSecondary(isDark),
              )),
              const SizedBox(height: 8),
              Text(
                _severityLabel(_severity, l10n),
                style: AppTextStyles.heading3.copyWith(
                  color: _severity > 7 ? AppColors.error(isDark) : AppColors.primary(isDark),
                ),
              ),
              const SizedBox(height: 16),
              Slider(
                value: _severity.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                activeColor: AppColors.primary(isDark),
                label: '$_severity',
                onChanged: (value) => setState(() => _severity = value.round()),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.triageSeverityMild, style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary(isDark),
                  )),
                  Text(l10n.triageSeveritySevere, style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary(isDark),
                  )),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Step 2: Duration
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildStep2Duration(bool isDark, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.triageQ2Title, style: AppTextStyles.heading2.copyWith(
          color: AppColors.textPrimary(isDark),
        )),
        const SizedBox(height: 8),
        Text(l10n.triageQ2Subtitle, style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary(isDark),
        )),
        const SizedBox(height: 24),
        ..._durationOptions.map((option) {
          final isSelected = _duration == option;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => setState(() => _duration = option),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryContainer(isDark)
                      : AppColors.cardBackground(isDark),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppColors.primary(isDark) : AppColors.outlineVariant(isDark),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: isSelected ? AppColors.primary(isDark) : AppColors.outline(isDark),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _durationLabel(option, l10n),
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.textPrimary(isDark),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Step 3: Age + biological sex
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildStep3AgeSex(bool isDark, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.triageQ3Title, style: AppTextStyles.heading2.copyWith(
          color: AppColors.textPrimary(isDark),
        )),
        const SizedBox(height: 8),
        Text(l10n.triageQ3Subtitle, style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary(isDark),
        )),
        const SizedBox(height: 24),
        // Age
        Text(l10n.age, style: AppTextStyles.labelLarge.copyWith(
          color: AppColors.textSecondary(isDark),
        )),
        const SizedBox(height: 8),
        TextFormField(
          controller: _ageController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: l10n.ageHint,
            suffixText: l10n.yearsSuffix,
          ),
        ),
        const SizedBox(height: 24),
        // Biological sex
        Text(l10n.biologicalSex, style: AppTextStyles.labelLarge.copyWith(
          color: AppColors.textSecondary(isDark),
        )),
        const SizedBox(height: 8),
        Row(
          children: ['male', 'female', 'other'].map((sex) {
            final isSelected = _biologicalSex == sex;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => setState(() => _biologicalSex = sex),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryContainer(isDark)
                          : AppColors.cardBackground(isDark),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primary(isDark) : AppColors.outlineVariant(isDark),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _sexLabel(sex, l10n),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: isSelected ? AppColors.primary(isDark) : AppColors.textPrimary(isDark),
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Step 4: Known conditions + medications
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildStep4Conditions(bool isDark, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.triageQ4Title, style: AppTextStyles.heading2.copyWith(
          color: AppColors.textPrimary(isDark),
        )),
        const SizedBox(height: 8),
        Text(l10n.triageQ4Subtitle, style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary(isDark),
        )),
        const SizedBox(height: 24),
        Text(l10n.chronicConditions, style: AppTextStyles.labelLarge.copyWith(
          color: AppColors.textSecondary(isDark),
        )),
        const SizedBox(height: 8),
        TextFormField(
          controller: _conditionsController,
          maxLines: 3,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: l10n.conditionsHint,
          ),
        ),
        const SizedBox(height: 16),
        Text(l10n.medications, style: AppTextStyles.labelLarge.copyWith(
          color: AppColors.textSecondary(isDark),
        )),
        const SizedBox(height: 8),
        TextFormField(
          controller: _medicationsController,
          maxLines: 3,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: l10n.medicationsHint,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Step 5: Notes + review
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildStep5Notes(bool isDark, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.triageQ5Title, style: AppTextStyles.heading2.copyWith(
          color: AppColors.textPrimary(isDark),
        )),
        const SizedBox(height: 8),
        Text(l10n.triageQ5Subtitle, style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary(isDark),
        )),
        const SizedBox(height: 24),
        TextFormField(
          controller: _notesController,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: l10n.notesHint,
          ),
        ),
        const SizedBox(height: 32),
        // Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground(isDark),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant(isDark)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.triageSummary, style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.textSecondary(isDark),
              )),
              const SizedBox(height: 12),
              _SummaryRow(label: l10n.symptoms, value: _selectedSymptoms.map((s) => _symptomLabel(s, l10n)).join(', ')),
              const SizedBox(height: 6),
              _SummaryRow(label: l10n.triageSeverityLabel, value: '$_severity/10 (${_severityLabel(_severity, l10n)})'),
              const SizedBox(height: 6),
              _SummaryRow(label: l10n.triageQ2Title, value: _duration != null ? _durationLabel(_duration!, l10n) : '—'),
              const SizedBox(height: 6),
              _SummaryRow(label: l10n.age, value: _ageController.text.isEmpty ? '—' : '${_ageController.text} ${l10n.yearsSuffix}'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(bool isDark, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        border: Border(top: BorderSide(color: AppColors.outlineVariant(isDark))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isStepValid && !_isProcessing ? _nextStep : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary(isDark),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isProcessing
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _currentStep == _totalSteps - 1
                            ? l10n.analyzeWithAi
                            : l10n.next,
                        style: AppTextStyles.button.copyWith(fontSize: 16),
                      ),
                      if (_currentStep == _totalSteps - 1) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.psychology, size: 20),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ── Label helpers ──
  String _symptomLabel(String key, AppLocalizations l10n) {
    // Try l10n first; fall back to humanized key
    try {
      switch (key) {
        case 'fever': return l10n.symptomFever;
        case 'headache': return l10n.symptomHeadache;
        case 'cough': return l10n.symptomCough;
        case 'shortness_of_breath': return l10n.symptomShortnessOfBreath;
        case 'fatigue': return l10n.symptomFatigue;
        case 'dizziness': return l10n.symptomDizziness;
        case 'nausea': return l10n.symptomNausea;
        case 'chills': return l10n.symptomChills;
        case 'muscle_ache': return l10n.symptomMuscleAche;
        case 'insomnia': return l10n.symptomInsomnia;
        case 'chest_pain': return l10n.symptomChestPain;
        case 'abdominal_pain': return l10n.symptomAbdominalPain;
        case 'sore_throat': return l10n.symptomSoreThroat;
        case 'runny_nose': return l10n.symptomRunnyNose;
        case 'vomiting': return l10n.symptomVomiting;
        case 'diarrhea': return l10n.symptomDiarrhea;
        case 'rash': return l10n.symptomRash;
        case 'joint_pain': return l10n.symptomJointPain;
        default: return key.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
      }
    } catch (_) {
      return key.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
    }
  }

  String _severityLabel(int severity, AppLocalizations l10n) {
    if (severity <= 2) return l10n.severityVeryMild;
    if (severity <= 4) return l10n.severityMild;
    if (severity <= 5) return l10n.severityModerate;
    if (severity <= 7) return l10n.severityDistracting;
    if (severity <= 9) return l10n.severitySevere;
    return l10n.severityUnbearable;
  }

  String _durationLabel(String key, AppLocalizations l10n) {
    switch (key) {
      case 'today': return l10n.durationToday;
      case '1_to_3_days': return l10n.duration1To3Days;
      case '4_to_7_days': return l10n.duration4To7Days;
      case '1_to_2_weeks': return l10n.duration1To2Weeks;
      case 'more_than_2_weeks': return l10n.durationMoreThan2Weeks;
      default: return key;
    }
  }

  String _sexLabel(String key, AppLocalizations l10n) {
    switch (key) {
      case 'male': return l10n.male;
      case 'female': return l10n.female;
      default: return l10n.other;
    }
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary(isDark),
          )),
        ),
        Expanded(
          child: Text(value, style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textPrimary(isDark),
          )),
        ),
      ],
    );
  }
}
