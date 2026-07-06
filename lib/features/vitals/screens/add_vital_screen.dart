import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/vital.dart';
import '../../../core/providers/vitals_provider.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_snack_bar.dart';

class AddVitalScreen extends ConsumerStatefulWidget {
  const AddVitalScreen({super.key});

  @override
  ConsumerState<AddVitalScreen> createState() => _AddVitalScreenState();
}

class _AddVitalScreenState extends ConsumerState<AddVitalScreen> {
  VitalType _selectedType = VitalType.heartRate;
  final _valueController = TextEditingController();
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDateTime = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _valueController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _isBloodPressure => _selectedType == VitalType.bloodPressure;

  /// Per-type validation ranges. Prevents garbage data like 99999 BPM or
  /// 5°C body temperature from being persisted to the DB.
  ///
  /// Ranges are inclusive; values outside trigger a snackbar and block save.
  (double, double) get _rangeFor {
    switch (_selectedType) {
      case VitalType.heartRate:
        return (30, 220);  // BPM
      case VitalType.respiratoryRate:
        return (8, 60);    // breaths per minute
      case VitalType.bloodPressure:
        return (60, 250);  // systolic; diastolic separately 40-150
      case VitalType.temperature:
        return (30, 45);   // °C
      case VitalType.spO2:
        return (50, 100);  // %
      case VitalType.bloodGlucose:
        return (20, 600);  // mg/dL
      case VitalType.weight:
        return (2, 500);   // kg
    }
  }

  String? _validationError() {
    final l10n = AppLocalizations.of(context)!;
    if (_isBloodPressure) {
      final sys = double.tryParse(_systolicController.text);
      final dia = double.tryParse(_diastolicController.text);
      if (sys == null || dia == null) return null;  // handled by _isValid
      if (sys < 60 || sys > 250) return l10n.vitalRangeHintBloodPressure;
      if (dia < 40 || dia > 150) return l10n.vitalRangeHintBloodPressure;
      if (sys <= dia) return l10n.vitalValueOutOfRange;
      return null;
    }
    final val = double.tryParse(_valueController.text);
    if (val == null) return null;  // handled by _isValid
    final (min, max) = _rangeFor;
    if (val < min || val > max) {
      return l10n.vitalValueOutOfRange;
    }
    return null;
  }

  bool get _isValid {
    if (_isBloodPressure) {
      final sys = double.tryParse(_systolicController.text);
      final dia = double.tryParse(_diastolicController.text);
      return sys != null && dia != null && sys > 0 && dia > 0 && _validationError() == null;
    }
    final val = double.tryParse(_valueController.text);
    return val != null && val > 0 && _validationError() == null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDateTime.hour,
          _selectedDateTime.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (picked != null) {
      setState(() {
        _selectedDateTime = DateTime(
          _selectedDateTime.year,
          _selectedDateTime.month,
          _selectedDateTime.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> _saveVital() async {
    // Show the validation error message when invalid (was silently returning).
    final err = _validationError();
    if (err != null) {
      AppSnackBar.error(context, err);
      return;
    }
    if (!_isValid) {
      AppSnackBar.error(context, AppLocalizations.of(context)!.vitalValueOutOfRange);
      return;
    }
    setState(() => _isSaving = true);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    try {
      if (_isBloodPressure) {
        await ref.read(vitalsProvider.notifier).addVital(
              _selectedType,
              double.parse(_systolicController.text),
              valueSecondary: double.parse(_diastolicController.text),
              notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
              recordedAt: _selectedDateTime,
            );
      } else {
        await ref.read(vitalsProvider.notifier).addVital(
              _selectedType,
              double.parse(_valueController.text),
              notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
              recordedAt: _selectedDateTime,
            );
      }

      if (mounted) {
        AppSnackBar.success(context, AppLocalizations.of(context)!.vitalSavedSuccessfully(_selectedType.displayName));
        if (Navigator.canPop(context)) { Navigator.pop(context); } else { context.go(AppConfig.dashboard); }
      }
    } catch (e) {
      if (mounted) AppSnackBar.errorFromException(context, AppLocalizations.of(context)!.vitalSaveFailed, e);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.logVitalTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vital Type Selector
            Text(
              l10n.vitalTypeLabel,
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textHint(isDark),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: VitalType.values.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final type = VitalType.values[index];
                  final isSelected = type == _selectedType;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedType = type;
                        _valueController.clear();
                        _systolicController.clear();
                        _diastolicController.clear();
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? type.color.withValues(alpha: 0.15)
                            : AppColors.subtleBackground(isDark),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isSelected
                              ? type.color
                              : AppColors.border(isDark),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(type.icon, size: 16, color: isSelected ? type.color : (AppColors.textHint(isDark))),
                          const SizedBox(width: 6),
                          Text(
                            type.displayName,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected
                                  ? type.color
                                  : isDark
                                      ? AppColors.grey400
                                      : AppColors.grey600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 28),

            // Value Input Section
            Text(
              l10n.valueLabel,
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textHint(isDark),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),

            if (_isBloodPressure) ...[
              // Systolic
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _systolicController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: false),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: l10n.systolic,
                        labelStyle: const TextStyle(fontFamily: 'Inter'),
                        suffixText: _selectedType.unit,
                        suffixStyle: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 12,
                          color: AppColors.textHint(isDark),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Diastolic
                  Expanded(
                    child: TextFormField(
                      controller: _diastolicController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: false),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: l10n.diastolic,
                        labelStyle: const TextStyle(fontFamily: 'Inter'),
                        suffixText: _selectedType.unit,
                        suffixStyle: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 12,
                          color: AppColors.textHint(isDark),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 18),
                    ),
                  ),
                ],
              ),
            ] else ...[
              TextFormField(
                controller: _valueController,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: _selectedType == VitalType.temperature,
                ),
                inputFormatters: [
                  _selectedType == VitalType.temperature
                      ? FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                      : FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  labelText: _selectedType.displayName,
                  labelStyle: const TextStyle(fontFamily: 'Inter'),
                  suffixText: _selectedType.unit,
                  suffixStyle: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12,
                    color: AppColors.textHint(isDark),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 18),
              ),
            ],
            const SizedBox(height: 24),

            // Date/Time Picker
            Text(
              l10n.dateTimeLabel,
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textHint(isDark),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.inputFill(isDark),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.border(isDark),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 18, color: AppColors.primary(isDark)),
                          const SizedBox(width: 10),
                          Text(
                            '${_selectedDateTime.day.toString().padLeft(2, '0')}/${_selectedDateTime.month.toString().padLeft(2, '0')}/${_selectedDateTime.year}',
                            style: TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 14,
                              color: isDark ? AppColors.grey300 : AppColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.inputFill(isDark),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.border(isDark),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, size: 18, color: AppColors.primary(isDark)),
                          const SizedBox(width: 10),
                          Text(
                            '${_selectedDateTime.hour.toString().padLeft(2, '0')}:${_selectedDateTime.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 14,
                              color: isDark ? AppColors.grey300 : AppColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Notes
            Text(
              l10n.notesOptionalLabel,
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textHint(isDark),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: l10n.notesHint,
                hintStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppColors.textTertiary(isDark),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
            ),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isValid && !_isSaving ? _saveVital : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary(isDark),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: (AppColors.primary(isDark)).withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            l10n.saveVitalType(_selectedType.displayName),
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
