import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/appointment.dart';
import '../../../core/providers/appointments_provider.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_snack_bar.dart';

class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen> {
  AppointmentStatus? _filterStatus;

  List<Appointment> _applyFilters(List<Appointment> appointments) {
    if (_filterStatus != null) {
      return appointments.where((a) => a.status == _filterStatus).toList();
    }
    return appointments;
  }

  Future<void> _markComplete(Appointment appointment) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(appointmentsProvider.notifier).updateAppointmentStatus(
            appointment.id,
            AppointmentStatus.completed,
          );
      if (mounted) AppSnackBar.success(context, l10n.appointmentMarkedCompleted);
    } catch (e) {
      if (mounted) AppSnackBar.errorFromException(context, l10n.failedToUpdateAppointment, e);
    }
  }

  Future<void> _cancelAppointment(Appointment appointment) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(appointmentsProvider.notifier).updateAppointmentStatus(
            appointment.id,
            AppointmentStatus.cancelled,
          );
      if (mounted) AppSnackBar.success(context, l10n.appointmentCancelled);
    } catch (e) {
      if (mounted) AppSnackBar.errorFromException(context, l10n.failedToCancelAppointment, e);
    }
  }

  Future<void> _rescheduleAppointment(Appointment appointment) async {
    final l10n = AppLocalizations.of(context)!;
    // Pick a new date.
    final newDate = await showDatePicker(
      context: context,
      initialDate: appointment.dateTime.isAfter(DateTime.now())
          ? appointment.dateTime
          : DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      helpText: l10n.selectNewDate,
    );
    if (newDate == null || !mounted) return;

    // Pick a new time.
    final newTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(appointment.dateTime),
      helpText: l10n.selectNewTime,
    );
    if (newTime == null || !mounted) return;

    final newDateTime = DateTime(
      newDate.year,
      newDate.month,
      newDate.day,
      newTime.hour,
      newTime.minute,
    );

    try {
      await ref.read(appointmentsProvider.notifier).rescheduleAppointment(
            appointmentId: appointment.id,
            newDateTime: newDateTime,
          );
      if (mounted) {
        AppSnackBar.success(
          context,
          l10n.rescheduledTo('${newDate.day}/${newDate.month}/${newDate.year}', newTime.format(context)),
        );
      }
    } catch (e) {
      if (mounted) AppSnackBar.errorFromException(context, l10n.failedToRescheduleAppointment, e);
    }
  }

  Future<void> _deleteAppointment(Appointment appointment) async {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteAppointment),
        content: Text(l10n.deleteAppointmentConfirm(appointment.doctorName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: isDark ? AppColors.darkError : AppColors.lightError),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(appointmentsProvider.notifier).deleteAppointment(appointment.id);
        if (mounted) AppSnackBar.success(context, l10n.appointmentDeleted);
      } catch (e) {
        if (mounted) AppSnackBar.errorFromException(context, l10n.failedToDeleteAppointment, e);
      }
    }
  }

  void _showCardActions(Appointment appointment) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      appointment.doctorName,
                      style: TextStyle(
                        fontFamily: 'ClashDisplay',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(isDark),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            if (appointment.status == AppointmentStatus.upcoming) ...[
              ListTile(
                leading: Icon(Icons.check_circle_outline, color: isDark ? AppColors.darkSuccess : AppColors.lightSuccess),
                title: Text(l10n.markComplete, style: const TextStyle(fontFamily: 'Inter')),
                onTap: () {
                  Navigator.pop(ctx);
                  _markComplete(appointment);
                },
              ),
              ListTile(
                leading: Icon(Icons.event_repeat, color: AppColors.primary(isDark)),
                title: Text(l10n.reschedule, style: const TextStyle(fontFamily: 'Inter')),
                onTap: () {
                  Navigator.pop(ctx);
                  _rescheduleAppointment(appointment);
                },
              ),
              ListTile(
                leading: Icon(Icons.cancel_outlined, color: isDark ? AppColors.darkWarning : AppColors.lightWarning),
                title: Text(l10n.cancelAppointment, style: const TextStyle(fontFamily: 'Inter')),
                onTap: () {
                  Navigator.pop(ctx);
                  _cancelAppointment(appointment);
                },
              ),
            ],
            ListTile(
              leading: Icon(Icons.delete_outline, color: isDark ? AppColors.darkError : AppColors.lightError),
              title: Text(l10n.delete, style: TextStyle(fontFamily: 'Inter', color: isDark ? AppColors.darkError : AppColors.lightError)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteAppointment(appointment);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final appointmentsAsync = ref.watch(appointmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appointments),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppConfig.addAppointment),
        backgroundColor: AppColors.primary(isDark),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: appointmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (appointments) {
          final filtered = _applyFilters(appointments);

          return Column(
            children: [
              // Filter chips
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    _StatusFilterChip(
                      label: l10n.all,
                      selected: _filterStatus == null,
                      onSelected: () => setState(() => _filterStatus = null),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _StatusFilterChip(
                      label: l10n.upcoming,
                      selected: _filterStatus == AppointmentStatus.upcoming,
                      onSelected: () => setState(() => _filterStatus =
                          _filterStatus == AppointmentStatus.upcoming
                              ? null
                              : AppointmentStatus.upcoming),
                      isDark: isDark,
                      color: AppColors.primary(isDark),
                    ),
                    const SizedBox(width: 8),
                    _StatusFilterChip(
                      label: l10n.completed,
                      selected: _filterStatus == AppointmentStatus.completed,
                      onSelected: () => setState(() => _filterStatus =
                          _filterStatus == AppointmentStatus.completed
                              ? null
                              : AppointmentStatus.completed),
                      isDark: isDark,
                      color: isDark ? AppColors.darkSuccess : AppColors.lightSuccess,
                    ),
                    const SizedBox(width: 8),
                    _StatusFilterChip(
                      label: l10n.cancelled,
                      selected: _filterStatus == AppointmentStatus.cancelled,
                      onSelected: () => setState(() => _filterStatus =
                          _filterStatus == AppointmentStatus.cancelled
                              ? null
                              : AppointmentStatus.cancelled),
                      isDark: isDark,
                      color: isDark ? AppColors.grey500 : AppColors.grey400,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Appointments list
              Expanded(
                child: appointments.isEmpty
                    ? _EmptyState(isDark: isDark, l10n: l10n)
                    : filtered.isEmpty
                        ? Center(
                            child: Text(
                              l10n.noAppointmentsMatchFilter,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: AppColors.textSecondary(isDark),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final appointment = filtered[index];
                              return _AppointmentCard(
                                appointment: appointment,
                                isDark: isDark,
                                onActionsTap: () => _showCardActions(appointment),
                                l10n: l10n,
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final bool isDark;
  final Color? color;

  const _StatusFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    required this.isDark,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppColors.primary(isDark);
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? chipColor : AppColors.subtleBackground(isDark),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? chipColor : AppColors.borderLight(isDark),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected
                ? Colors.white
                : isDark
                    ? AppColors.grey400
                    : AppColors.grey600,
          ),
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final bool isDark;
  final VoidCallback onActionsTap;
  final AppLocalizations l10n;

  const _AppointmentCard({
    required this.appointment,
    required this.isDark,
    required this.onActionsTap,
    required this.l10n,
  });

  Color _statusColor() {
    switch (appointment.status) {
      case AppointmentStatus.upcoming:
        return AppColors.primary(isDark);
      case AppointmentStatus.completed:
        return isDark ? AppColors.darkSuccess : AppColors.lightSuccess;
      case AppointmentStatus.cancelled:
        return isDark ? AppColors.grey500 : AppColors.grey400;
    }
  }

  IconData _statusIcon() {
    switch (appointment.status) {
      case AppointmentStatus.upcoming:
        return Icons.schedule;
      case AppointmentStatus.completed:
        return Icons.check_circle;
      case AppointmentStatus.cancelled:
        return Icons.cancel;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: doctor icon + name + status chip + menu
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _statusColor().withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.person, color: _statusColor(), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.doctorName,
                        style: TextStyle(
                          fontFamily: 'ClashDisplay',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(isDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (appointment.specialty != null) ...[
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.secondary(isDark).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            appointment.specialty!,
                            style: TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary(isDark),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor().withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(), size: 12, color: _statusColor()),
                      const SizedBox(width: 4),
                      Text(
                        appointment.status.displayName,
                        style: TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _statusColor(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onActionsTap,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.more_vert,
                      color: AppColors.textHint(isDark),
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Date/Time row
            Row(
              children: [
                Icon(
                  Icons.event_outlined,
                  size: 14,
                  color: AppColors.textHint(isDark),
                ),
                const SizedBox(width: 4),
                Text(
                  appointment.displayDate,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: AppColors.textHint(isDark),
                ),
                const SizedBox(width: 4),
                Text(
                  appointment.displayTime,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
              ],
            ),

            // Location row
            if (appointment.location != null && appointment.location!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: AppColors.textHint(isDark),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      appointment.location!,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.textSecondary(isDark),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isDark;
  final AppLocalizations l10n;
  const _EmptyState({required this.isDark, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 80,
              color: AppColors.textTertiary(isDark),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noAppointmentsYet,
              style: TextStyle(
                fontFamily: 'ClashDisplay',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.scheduleFirstAppointment,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.textHint(isDark),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
