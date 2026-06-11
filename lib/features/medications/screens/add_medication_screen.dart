import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/medication.dart';
import '../../../core/providers/medications_provider.dart';
import '../../../shared/theme/app_colors.dart';

class AddMedicationScreen extends ConsumerStatefulWidget {
  const AddMedicationScreen({super.key});

  @override
  ConsumerState<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends ConsumerState<AddMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _notesController = TextEditingController();

  MedicationFrequency _frequency = MedicationFrequency.onceDaily;
  String _unit = 'mg';
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _hasEndDate = false;
  bool _remindersEnabled = true;
  bool _isSaving = false;
  List<TimeOfDay> _doseTimes = [const TimeOfDay(hour: 8, minute: 0)];

  static const List<String> _units = ['mg', 'mcg', 'mL', 'g', 'IU', 'drops', 'puffs', 'tablets', 'capsules'];

  int get _requiredDoseTimes {
    switch (_frequency) {
      case MedicationFrequency.onceDaily:
        return 1;
      case MedicationFrequency.twiceDaily:
        return 2;
      case MedicationFrequency.threeTimesDaily:
        return 3;
      case MedicationFrequency.fourTimesDaily:
        return 4;
      case MedicationFrequency.everyOtherDay:
        return 1;
      case MedicationFrequency.weekly:
        return 1;
      case MedicationFrequency.asNeeded:
        return 0;
      case MedicationFrequency.custom:
        return 1;
    }
  }

  void _updateDoseTimes() {
    final required = _requiredDoseTimes;
    while (_doseTimes.length < required) {
      _doseTimes.add(TimeOfDay(
        hour: 8 + _doseTimes.length * 4,
        minute: 0,
      ));
    }
    while (_doseTimes.length > required && _doseTimes.isNotEmpty) {
      _doseTimes.removeLast();
    }
    setState(() {});
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 30)),
      firstDate: _startDate,
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _selectDoseTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _doseTimes[index],
    );
    if (picked != null) {
      setState(() => _doseTimes[index] = picked);
    }
  }

  Future<void> _saveMedication() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final times = _doseTimes.map((t) {
        return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      }).toList();

      await ref.read(medicationsProvider.notifier).addMedication(
            name: _nameController.text.trim(),
            dosage: _dosageController.text.trim(),
            unit: _unit,
            frequency: _frequency,
            times: times,
            startDate: _startDate,
            endDate: _hasEndDate ? _endDate : null,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            remindersEnabled: _remindersEnabled,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medication added successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.lightError),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Medication'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Medication Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Medication Name',
                  labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                  prefixIcon: const Icon(Icons.medication_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  color: isDark ? Colors.white : AppColors.lightOnBackground,
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Dosage row: value + unit
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _dosageController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Dosage',
                        labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                        prefixIcon: const Icon(Icons.straighten),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        color: isDark ? Colors.white : AppColors.lightOnBackground,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      value: _unit,
                      decoration: InputDecoration(
                        labelText: 'Unit',
                        labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        color: isDark ? Colors.white : AppColors.lightOnBackground,
                      ),
                      items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                      onChanged: (v) => setState(() => _unit = v ?? 'mg'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Frequency dropdown
              DropdownButtonFormField<MedicationFrequency>(
                value: _frequency,
                decoration: InputDecoration(
                  labelText: 'Frequency',
                  labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                  prefixIcon: const Icon(Icons.repeat),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  color: isDark ? Colors.white : AppColors.lightOnBackground,
                ),
                items: MedicationFrequency.values
                    .map((f) => DropdownMenuItem(
                          value: f,
                          child: Text(f.displayName),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _frequency = v);
                    _updateDoseTimes();
                  }
                },
              ),
              const SizedBox(height: 16),

              // Start Date
              _DateField(
                label: 'Start Date',
                date: _startDate,
                isDark: isDark,
                onTap: _selectStartDate,
              ),
              const SizedBox(height: 12),

              // End Date toggle + picker
              Row(
                children: [
                  Switch(
                    value: _hasEndDate,
                    onChanged: (v) => setState(() => _hasEndDate = v),
                    activeColor: AppColors.lightPrimary,
                  ),
                  Text(
                    'Set end date',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: isDark ? AppColors.grey300 : AppColors.grey700,
                    ),
                  ),
                ],
              ),
              if (_hasEndDate) ...[
                const SizedBox(height: 4),
                _DateField(
                  label: 'End Date',
                  date: _endDate ?? _startDate.add(const Duration(days: 30)),
                  isDark: isDark,
                  onTap: _selectEndDate,
                ),
                const SizedBox(height: 16),
              ],

              // Dose times
              if (_requiredDoseTimes > 0) ...[
                Text(
                  'DOSE TIMES',
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.grey500 : AppColors.grey400,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                ...List.generate(_doseTimes.length, (index) {
                  final time = _doseTimes[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () => _selectDoseTime(index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E2230) : AppColors.grey50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2A2F3E) : AppColors.grey100,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 18,
                              color: isDark ? AppColors.grey400 : AppColors.grey500,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Dose ${index + 1}',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: isDark ? AppColors.grey300 : AppColors.grey600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontFamily: 'DMSans',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : AppColors.lightOnBackground,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: isDark ? AppColors.grey500 : AppColors.grey400,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],

              // Notes
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 48),
                    child: Icon(Icons.note_outlined),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  alignLabelWithHint: true,
                ),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  color: isDark ? Colors.white : AppColors.lightOnBackground,
                ),
              ),
              const SizedBox(height: 16),

              // Reminders toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2230) : AppColors.grey50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2A2F3E) : AppColors.grey100,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_outlined,
                      color: AppColors.lightPrimary,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Reminders',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : AppColors.lightOnBackground,
                        ),
                      ),
                    ),
                    Switch(
                      value: _remindersEnabled,
                      onChanged: (v) => setState(() => _remindersEnabled = v),
                      activeColor: AppColors.lightPrimary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveMedication,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.lightPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Save Medication',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final bool isDark;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.date,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2230) : AppColors.grey50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2F3E) : AppColors.grey100,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: isDark ? AppColors.grey400 : AppColors.grey500,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: isDark ? AppColors.grey300 : AppColors.grey600,
              ),
            ),
            const Spacer(),
            Text(
              '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.lightOnBackground,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: isDark ? AppColors.grey500 : AppColors.grey400,
            ),
          ],
        ),
      ),
    );
  }
}
