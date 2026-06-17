import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

  bool get _isValid {
    if (_isBloodPressure) {
      final sys = double.tryParse(_systolicController.text);
      final dia = double.tryParse(_diastolicController.text);
      return sys != null && dia != null && sys > 0 && dia > 0;
    }
    final val = double.tryParse(_valueController.text);
    return val != null && val > 0;
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
    if (!_isValid) return;
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
        AppSnackBar.success(context, '${_selectedType.displayName} saved successfully');
        context.pop();
      }
    } catch (e) {
      if (mounted) AppSnackBar.errorFromException(context, 'Failed to save vital. Please try again.', e);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Log Vital')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vital Type Selector
            Text(
              'VITAL TYPE',
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
              'VALUE',
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
                        labelText: 'Systolic',
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
                        labelText: 'Diastolic',
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
              'DATE & TIME',
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
              'NOTES (OPTIONAL)',
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
                hintText: 'Add any notes about this reading...',
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
                            'Save ${_selectedType.displayName}',
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
