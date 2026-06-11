import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/appointments_provider.dart';
import '../../../shared/theme/app_colors.dart';

class AddAppointmentScreen extends ConsumerStatefulWidget {
  const AddAppointmentScreen({super.key});

  @override
  ConsumerState<AddAppointmentScreen> createState() => _AddAppointmentScreenState();
}

class _AddAppointmentScreenState extends ConsumerState<AddAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _doctorNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  String? _specialty;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  bool _reminderEnabled = true;
  bool _isSaving = false;

  static const List<String> _specialties = [
    'Cardiologist',
    'Dermatologist',
    'Endocrinologist',
    'General Practice',
    'Neurologist',
    'Ophthalmologist',
    'Orthopedic',
    'Pediatrician',
    'Psychiatrist',
    'Other',
  ];

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _saveAppointment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      await ref.read(appointmentsProvider.notifier).addAppointment(
            doctorName: _doctorNameController.text.trim(),
            specialty: _specialty,
            dateTime: dateTime,
            location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            reminderEnabled: _reminderEnabled,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment scheduled successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error(Theme.of(context).brightness == Brightness.dark)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _doctorNameController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Appointment'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Doctor Name
              TextFormField(
                controller: _doctorNameController,
                decoration: InputDecoration(
                  labelText: 'Doctor Name',
                  labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                  prefixIcon: const Icon(Icons.person_outline),
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

              // Specialty dropdown
              DropdownButtonFormField<String>(
                value: _specialty,
                decoration: InputDecoration(
                  labelText: 'Specialty',
                  labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                  prefixIcon: const Icon(Icons.local_hospital_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  color: isDark ? Colors.white : AppColors.lightOnBackground,
                ),
                hint: Text(
                  'Select specialty',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    color: isDark ? AppColors.grey500 : AppColors.grey400,
                  ),
                ),
                items: _specialties
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _specialty = v),
              ),
              const SizedBox(height: 16),

              // Date picker
              GestureDetector(
                onTap: _selectDate,
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
                        'Date',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: isDark ? AppColors.grey300 : AppColors.grey600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
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
              ),
              const SizedBox(height: 12),

              // Time picker
              GestureDetector(
                onTap: _selectTime,
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
                        'Time',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: isDark ? AppColors.grey300 : AppColors.grey600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
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
              ),
              const SizedBox(height: 16),

              // Location
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'Location / Address (optional)',
                  labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  color: isDark ? Colors.white : AppColors.lightOnBackground,
                ),
              ),
              const SizedBox(height: 16),

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

              // Reminder toggle
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
                      color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Reminder',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : AppColors.lightOnBackground,
                        ),
                      ),
                    ),
                    Switch(
                      value: _reminderEnabled,
                      onChanged: (v) => setState(() => _reminderEnabled = v),
                      activeColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
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
                  onPressed: _isSaving ? null : _saveAppointment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
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
                          'Save Appointment',
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
