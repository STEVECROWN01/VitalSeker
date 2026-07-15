import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import '../../../core/providers/appointments_provider.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/widgets/pro_feature_gate.dart';

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
    // Validate the form. If validation fails (empty required fields, etc.),
    // the form fields will display their error messages and we abort.
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context)!;

    setState(() => _isSaving = true);
    try {
      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // CRITICAL FIX (audit C-13): validate that the appointment time is in
      // the future. The date picker restricts to today-or-later, but the
      // time picker has no such restriction — a user can pick today's date
      // and a time earlier than now (e.g. it's 15:00 and they pick 09:00),
      // creating an "upcoming" appointment that's already in the past.
      // Such an appointment would never trigger a reminder and would
      // confuse the appointments list.
      if (dateTime.isBefore(DateTime.now())) {
        if (mounted) {
          AppSnackBar.error(
            context,
            'Appointment time must be in the future. Please pick a later time.',
          );
        }
        return;
      }

      await ref.read(appointmentsProvider.notifier).addAppointment(
            doctorName: _doctorNameController.text.trim(),
            specialty: _specialty,
            dateTime: dateTime,
            location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            reminderEnabled: _reminderEnabled,
          );

      if (mounted) {
        AppSnackBar.success(context, l10n.appointmentScheduledSuccessfully);
        if (Navigator.canPop(context)) { Navigator.pop(context); } else { context.go(AppConfig.appointments); }
      }
    } catch (e) {
      if (mounted) AppSnackBar.errorFromException(context, l10n.appointmentScheduleFailed, e);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _specialtyLabel(AppLocalizations l10n, String specialty) {
    switch (specialty) {
      case 'Cardiologist':
        return l10n.specialtyCardiologist;
      case 'Dermatologist':
        return l10n.specialtyDermatologist;
      case 'Endocrinologist':
        return l10n.specialtyEndocrinologist;
      case 'General Practice':
        return l10n.specialtyGeneralPractice;
      case 'Neurologist':
        return l10n.specialtyNeurologist;
      case 'Ophthalmologist':
        return l10n.specialtyOphthalmologist;
      case 'Orthopedic':
        return l10n.specialtyOrthopedic;
      case 'Pediatrician':
        return l10n.specialtyPediatrician;
      case 'Psychiatrist':
        return l10n.specialtyPsychiatrist;
      case 'Other':
        return l10n.specialtyOther;
      default:
        return specialty;
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
    final l10n = AppLocalizations.of(context)!;

    // ── Pro gate ──
    // Adding appointments is a Pro-only feature. If a free user deep-links
    // here directly, show the ProFeatureGate upsell instead of the form.
    final isPro = ref.watch(isProUserProvider);
    if (!isPro) {
      return const ProFeatureGate(
        featureName: 'Appointment Manager',
        featureDescription: 'Schedule and track doctor appointments. Set reminders, reschedule, and keep a complete history of your medical visits.',
        featureIcon: Icons.event,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.addAppointmentTitle),
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
                  labelText: l10n.doctorNameLabel,
                  labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  color: AppColors.textPrimary(isDark),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? l10n.fieldRequired : null,
              ),
              const SizedBox(height: 16),

              // Specialty dropdown
              DropdownButtonFormField<String>(
                dropdownColor: AppColors.surface(isDark),
                value: _specialty,
                decoration: InputDecoration(
                  labelText: l10n.specialtyLabel,
                  labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                  prefixIcon: const Icon(Icons.local_hospital_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  color: AppColors.textPrimary(isDark),
                ),
                hint: Text(
                  l10n.selectSpecialtyHint,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    color: AppColors.textHint(isDark),
                  ),
                ),
                items: _specialties
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(_specialtyLabel(l10n, s)),
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
                    color: AppColors.inputFill(isDark),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.borderLight(isDark),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: AppColors.textSecondary(isDark),
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
                          color: AppColors.textPrimary(isDark),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AppColors.textHint(isDark),
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
                    color: AppColors.inputFill(isDark),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.borderLight(isDark),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 18,
                        color: AppColors.textSecondary(isDark),
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
                          color: AppColors.textPrimary(isDark),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AppColors.textHint(isDark),
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
                  labelText: l10n.locationOptional,
                  labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.notesOptional,
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
                  color: AppColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 16),

              // Reminder toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.subtleBackground(isDark),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.borderLight(isDark),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_outlined,
                      color: AppColors.primary(isDark),
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.reminderLabel,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary(isDark),
                        ),
                      ),
                    ),
                    Switch(
                      value: _reminderEnabled,
                      onChanged: (v) => setState(() => _reminderEnabled = v),
                      activeColor: AppColors.primary(isDark),
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
                    backgroundColor: AppColors.primary(isDark),
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
                      : Text(
                          l10n.saveAppointment,
                          style: const TextStyle(
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
