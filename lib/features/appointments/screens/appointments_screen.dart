import 'package:flutter/material.dart';
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
    try {
      await ref.read(appointmentsProvider.notifier).updateAppointmentStatus(
            appointment.id,
            AppointmentStatus.completed,
          );
      if (mounted) AppSnackBar.success(context, 'Appointment marked as completed');
    } catch (e) {
      if (mounted) AppSnackBar.errorFromException(context, 'Failed to update appointment.', e);
    }
  }

  Future<void> _cancelAppointment(Appointment appointment) async {
    try {
      await ref.read(appointmentsProvider.notifier).updateAppointmentStatus(
            appointment.id,
            AppointmentStatus.cancelled,
          );
      if (mounted) AppSnackBar.success(context, 'Appointment cancelled');
    } catch (e) {
      if (mounted) AppSnackBar.errorFromException(context, 'Failed to cancel appointment.', e);
    }
  }

  Future<void> _deleteAppointment(Appointment appointment) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Appointment'),
        content: Text('Are you sure you want to delete the appointment with ${appointment.doctorName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: isDark ? AppColors.darkError : AppColors.lightError),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(appointmentsProvider.notifier).deleteAppointment(appointment.id);
        if (mounted) AppSnackBar.success(context, 'Appointment deleted');
      } catch (e) {
        if (mounted) AppSnackBar.errorFromException(context, 'Failed to delete appointment.', e);
      }
    }
  }

  void _showCardActions(Appointment appointment) {
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
                title: const Text('Mark Complete', style: TextStyle(fontFamily: 'Inter')),
                onTap: () {
                  Navigator.pop(ctx);
                  _markComplete(appointment);
                },
              ),
              ListTile(
                leading: Icon(Icons.cancel_outlined, color: isDark ? AppColors.darkWarning : AppColors.lightWarning),
                title: const Text('Cancel Appointment', style: TextStyle(fontFamily: 'Inter')),
                onTap: () {
                  Navigator.pop(ctx);
                  _cancelAppointment(appointment);
                },
              ),
            ],
            ListTile(
              leading: Icon(Icons.delete_outline, color: isDark ? AppColors.darkError : AppColors.lightError),
              title: Text('Delete', style: TextStyle(fontFamily: 'Inter', color: isDark ? AppColors.darkError : AppColors.lightError)),
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
    final appointmentsAsync = ref.watch(appointmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointments'),
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
                      label: 'All',
                      selected: _filterStatus == null,
                      onSelected: () => setState(() => _filterStatus = null),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _StatusFilterChip(
                      label: 'Upcoming',
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
                      label: 'Completed',
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
                      label: 'Cancelled',
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
                    ? _EmptyState(isDark: isDark)
                    : filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No appointments match the filter',
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

  const _AppointmentCard({
    required this.appointment,
    required this.isDark,
    required this.onActionsTap,
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
  const _EmptyState({required this.isDark});

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
              'No Appointments Yet',
              style: TextStyle(
                fontFamily: 'ClashDisplay',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Schedule your first appointment to\nkeep track of visits',
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
