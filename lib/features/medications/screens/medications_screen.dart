import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/medication.dart';
import '../../../core/providers/medications_provider.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_snack_bar.dart';

class MedicationsScreen extends ConsumerStatefulWidget {
  const MedicationsScreen({super.key});

  @override
  ConsumerState<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends ConsumerState<MedicationsScreen> {
  String _searchQuery = '';
  MedicationStatus? _filterStatus;

  List<Medication> _applyFilters(List<Medication> medications) {
    var filtered = medications;
    if (_filterStatus != null) {
      filtered = filtered.where((m) => m.status == _filterStatus).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((m) => m.name.toLowerCase().contains(query)).toList();
    }
    return filtered;
  }

  Future<void> _discontinue(Medication medication) async {
    try {
      await ref.read(medicationsProvider.notifier).updateMedicationStatus(
            medication.id,
            MedicationStatus.discontinued,
          );
      if (mounted) AppSnackBar.success(context, 'Medication discontinued');
    } catch (e) {
      if (mounted) AppSnackBar.errorFromException(context, 'Failed to discontinue medication.', e);
    }
  }

  void _showEditMedicationDialog(Medication medication) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dosageController = TextEditingController(text: medication.dosage);
    final notesController = TextEditingController(text: medication.notes ?? '');
    String unit = medication.unit;
    MedicationFrequency frequency = medication.frequency;
    bool reminders = medication.remindersEnabled;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Edit ${medication.name}', style: const TextStyle(fontFamily: 'ClashDisplay')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: dosageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Dosage',
                    prefixIcon: Icon(Icons.science_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: unit,
                  decoration: const InputDecoration(labelText: 'Unit'),
                  items: const ['mg', 'mcg', 'mL', 'g', 'IU', 'drops', 'puffs', 'tablets', 'capsules']
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => unit = v ?? unit),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<MedicationFrequency>(
                  value: frequency,
                  decoration: const InputDecoration(labelText: 'Frequency'),
                  items: MedicationFrequency.values
                      .map((f) => DropdownMenuItem(
                            value: f,
                            child: Text(_frequencyLabel(f)),
                          ))
                      .toList(),
                  onChanged: (v) => setDialogState(() => frequency = v ?? frequency),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Reminders'),
                  value: reminders,
                  onChanged: (v) => setDialogState(() => reminders = v),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (dosageController.text.trim().isEmpty) return;
                      setDialogState(() => isSaving = true);
                      try {
                        await ref.read(medicationsProvider.notifier).updateMedicationDetails(
                              medicationId: medication.id,
                              dosage: dosageController.text.trim(),
                              unit: unit,
                              frequency: frequency,
                              times: medication.times,
                              endDate: medication.endDate,
                              notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                              remindersEnabled: reminders,
                            );
                        if (mounted) {
                          Navigator.pop(ctx);
                          AppSnackBar.success(context, 'Medication updated!');
                        }
                      } catch (e) {
                        if (mounted) {
                          setDialogState(() => isSaving = false);
                          AppSnackBar.errorFromException(context, 'Failed to update medication.', e);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary(isDark)),
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markComplete(Medication medication) async {
    try {
      await ref.read(medicationsProvider.notifier).updateMedicationStatus(
            medication.id,
            MedicationStatus.completed,
          );
      if (mounted) AppSnackBar.success(context, 'Medication marked as completed');
    } catch (e) {
      if (mounted) AppSnackBar.errorFromException(context, 'Failed to update medication.', e);
    }
  }

  static String _frequencyLabel(MedicationFrequency f) {
    switch (f) {
      case MedicationFrequency.onceDaily:
        return 'Once Daily';
      case MedicationFrequency.twiceDaily:
        return 'Twice Daily';
      case MedicationFrequency.threeTimesDaily:
        return 'Three Times Daily';
      case MedicationFrequency.fourTimesDaily:
        return 'Four Times Daily';
      case MedicationFrequency.everyOtherDay:
        return 'Every Other Day';
      case MedicationFrequency.weekly:
        return 'Weekly';
      case MedicationFrequency.asNeeded:
        return 'As Needed';
      case MedicationFrequency.custom:
        return 'Custom';
    }
  }

  Future<void> _deleteMedication(Medication medication) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Medication'),
        content: Text('Are you sure you want to delete ${medication.name}?'),
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
        await ref.read(medicationsProvider.notifier).deleteMedication(medication.id);
        if (mounted) AppSnackBar.success(context, 'Medication deleted');
      } catch (e) {
        if (mounted) AppSnackBar.errorFromException(context, 'Failed to delete medication.', e);
      }
    }
  }

  void _showCardMenu(Medication medication) {
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
                      medication.name,
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
            if (medication.status == MedicationStatus.active) ...[
              ListTile(
                leading: Icon(Icons.edit_outlined, color: AppColors.primary(isDark)),
                title: const Text('Edit Details', style: TextStyle(fontFamily: 'Inter')),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditMedicationDialog(medication);
                },
              ),
              ListTile(
                leading: Icon(Icons.check_circle_outline, color: isDark ? AppColors.darkSuccess : AppColors.lightSuccess),
                title: const Text('Mark Complete', style: TextStyle(fontFamily: 'Inter')),
                onTap: () {
                  Navigator.pop(ctx);
                  _markComplete(medication);
                },
              ),
              ListTile(
                leading: Icon(Icons.block, color: isDark ? AppColors.darkWarning : AppColors.lightWarning),
                title: const Text('Discontinue', style: TextStyle(fontFamily: 'Inter')),
                onTap: () {
                  Navigator.pop(ctx);
                  _discontinue(medication);
                },
              ),
            ],
            ListTile(
              leading: Icon(Icons.delete_outline, color: isDark ? AppColors.darkError : AppColors.lightError),
              title: Text('Delete', style: TextStyle(fontFamily: 'Inter', color: isDark ? AppColors.darkError : AppColors.lightError)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteMedication(medication);
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
    final medicationsAsync = ref.watch(medicationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medications'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppConfig.addMedication),
        backgroundColor: AppColors.primary(isDark),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: medicationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (medications) {
          final filtered = _applyFilters(medications);

          return Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search medications...',
                    hintStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: AppColors.textHint(isDark),
                    ),
                    prefixIcon: Icon(Icons.search, color: AppColors.textHint(isDark)),
                    filled: true,
                    fillColor: AppColors.inputFill(isDark),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Filter chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Active',
                      selected: _filterStatus == MedicationStatus.active,
                      onSelected: () => setState(() => _filterStatus =
                          _filterStatus == MedicationStatus.active ? null : MedicationStatus.active),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Completed',
                      selected: _filterStatus == MedicationStatus.completed,
                      onSelected: () => setState(() => _filterStatus =
                          _filterStatus == MedicationStatus.completed ? null : MedicationStatus.completed),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'All',
                      selected: _filterStatus == null,
                      onSelected: () => setState(() => _filterStatus = null),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Medications list
              Expanded(
                child: medications.isEmpty
                    ? _EmptyState(isDark: isDark)
                    : filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No medications match your search',
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
                              final medication = filtered[index];
                              return _MedicationCard(
                                medication: medication,
                                isDark: isDark,
                                onMenuTap: () => _showCardMenu(medication),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final bool isDark;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary(isDark)
              : AppColors.subtleBackground(isDark),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.primary(isDark)
                : AppColors.borderLight(isDark),
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

class _MedicationCard extends StatelessWidget {
  final Medication medication;
  final bool isDark;
  final VoidCallback onMenuTap;

  const _MedicationCard({
    required this.medication,
    required this.isDark,
    required this.onMenuTap,
  });

  Color _statusColor() {
    switch (medication.status) {
      case MedicationStatus.active:
        return AppColors.primary(isDark);
      case MedicationStatus.completed:
        return isDark ? AppColors.darkSuccess : AppColors.lightSuccess;
      case MedicationStatus.discontinued:
        return isDark ? AppColors.grey500 : AppColors.grey400;
    }
  }

  String _statusLabel() {
    switch (medication.status) {
      case MedicationStatus.active:
        return 'Active';
      case MedicationStatus.completed:
        return 'Completed';
      case MedicationStatus.discontinued:
        return 'Discontinued';
    }
  }

  @override
  Widget build(BuildContext context) {
    final adherence = medication.adherencePercentage;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: name + status + menu
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _statusColor().withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.medication, color: _statusColor(), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medication.name,
                        style: TextStyle(
                          fontFamily: 'ClashDisplay',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(isDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${medication.displayDosage} • ${medication.displayFrequency}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: AppColors.textSecondary(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor().withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusLabel(),
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _statusColor(),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onMenuTap,
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

            // Next dose time
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 14,
                  color: AppColors.textHint(isDark),
                ),
                const SizedBox(width: 4),
                Text(
                  'Next dose: ${medication.nextDoseTime}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Adherence progress bar
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: adherence / 100,
                      backgroundColor: AppColors.borderLight(isDark),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        adherence >= 80
                            ? (isDark ? AppColors.darkSuccess : AppColors.lightSuccess)
                            : adherence >= 50
                                ? (isDark ? AppColors.darkWarning : AppColors.lightWarning)
                                : (isDark ? AppColors.darkError : AppColors.lightError),
                      ),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${adherence.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
              ],
            ),
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
              Icons.medication_outlined,
              size: 80,
              color: AppColors.textTertiary(isDark),
            ),
            const SizedBox(height: 16),
            Text(
              'No Medications Yet',
              style: TextStyle(
                fontFamily: 'ClashDisplay',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your medications to track dosages,\nfrequency, and adherence',
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
