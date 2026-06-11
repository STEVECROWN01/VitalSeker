import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/medication.dart';
import '../../../core/providers/medications_provider.dart';
import '../../../shared/theme/app_colors.dart';

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

  Future<void> _markComplete(Medication medication) async {
    try {
      await ref.read(medicationsProvider.notifier).updateMedicationStatus(
            medication.id,
            MedicationStatus.completed,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medication marked as completed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error(Theme.of(context).brightness == Brightness.dark)),
        );
      }
    }
  }

  Future<void> _deleteMedication(Medication medication) async {
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Medication deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error(Theme.of(context).brightness == Brightness.dark)),
          );
        }
      }
    }
  }

  void _showCardMenu(Medication medication) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
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
                        color: isDark ? Colors.white : AppColors.lightOnBackground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            if (medication.status == MedicationStatus.active)
              ListTile(
                leading: Icon(Icons.check_circle_outline, color: isDark ? AppColors.darkSuccess : AppColors.lightSuccess),
                title: const Text('Mark Complete', style: TextStyle(fontFamily: 'Inter')),
                onTap: () {
                  Navigator.pop(ctx);
                  _markComplete(medication);
                },
              ),
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
        backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
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
                      color: isDark ? AppColors.grey500 : AppColors.grey400,
                    ),
                    prefixIcon: Icon(Icons.search, color: isDark ? AppColors.grey500 : AppColors.grey400),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E2230) : AppColors.grey50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: isDark ? Colors.white : AppColors.lightOnBackground,
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
                                color: isDark ? AppColors.grey400 : AppColors.grey500,
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
              ? (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
              : isDark
                  ? const Color(0xFF1E2230)
                  : AppColors.grey50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
                : isDark
                    ? const Color(0xFF2A2F3E)
                    : AppColors.grey100,
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
        return isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
      case MedicationStatus.completed:
        return isDark ? AppColors.darkSuccess : AppColors.lightSuccess;
      case MedicationStatus.discontinued:
        return AppColors.grey400;
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
                          color: isDark ? Colors.white : AppColors.lightOnBackground,
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
                          color: isDark ? AppColors.grey400 : AppColors.grey500,
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
                      color: isDark ? AppColors.grey500 : AppColors.grey400,
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
                  color: isDark ? AppColors.grey500 : AppColors.grey400,
                ),
                const SizedBox(width: 4),
                Text(
                  'Next dose: ${medication.nextDoseTime}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: isDark ? AppColors.grey400 : AppColors.grey500,
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
                      backgroundColor: isDark ? const Color(0xFF2A2F3E) : AppColors.grey100,
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
                    color: isDark ? AppColors.grey400 : AppColors.grey500,
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
              color: isDark ? AppColors.grey600 : AppColors.grey300,
            ),
            const SizedBox(height: 16),
            Text(
              'No Medications Yet',
              style: TextStyle(
                fontFamily: 'ClashDisplay',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.grey400 : AppColors.grey500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your medications to track dosages,\nfrequency, and adherence',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: isDark ? AppColors.grey500 : AppColors.grey400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
