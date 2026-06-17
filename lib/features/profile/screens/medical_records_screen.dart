import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_snack_bar.dart';

enum RecordType { all, labResults, prescriptions, imaging, other }

class MedicalRecordsScreen extends ConsumerStatefulWidget {
  const MedicalRecordsScreen({super.key});

  @override
  ConsumerState<MedicalRecordsScreen> createState() => _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends ConsumerState<MedicalRecordsScreen> {
  final _searchController = TextEditingController();
  RecordType _selectedFilter = RecordType.all;
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    try {
      final db = ref.read(databaseServiceProvider);
      final records = await db.getMedicalRecords(user.id);
      if (mounted) {
        setState(() {
          _records = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppSnackBar.errorFromException(context, 'Failed to load records. Please try again.', e);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredRecords {
    var records = _records;

    // Filter by type
    if (_selectedFilter != RecordType.all) {
      final typeString = _selectedFilter.name;
      records = records.where((r) => r['type'] == typeString).toList();
    }

    // Filter by search
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      records = records.where((r) {
        final title = (r['title'] ?? '').toString().toLowerCase();
        final desc = (r['description'] ?? '').toString().toLowerCase();
        return title.contains(query) || desc.contains(query);
      }).toList();
    }

    return records;
  }

  IconData _typeIcon(String? type) {
    switch (type) {
      case 'labResults':
        return Icons.science_outlined;
      case 'prescriptions':
        return Icons.medication_outlined;
      case 'imaging':
        return Icons.image_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  Color _typeColor(String? type) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (type) {
      case 'labResults':
        return isDark ? AppColors.darkInfo : AppColors.lightInfo;
      case 'prescriptions':
        return AppColors.primary(isDark);
      case 'imaging':
        return isDark ? AppColors.darkSecondary : AppColors.lightSecondary;
      default:
        return isDark ? AppColors.darkWarning : AppColors.lightWarning;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  void _showAddRecordDialog() {
    _showRecordDialog(record: null);
  }

  void _showEditRecordDialog(Map<String, dynamic> record) {
    _showRecordDialog(record: record);
  }

  void _showRecordDialog({Map<String, dynamic>? record}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = record != null;
    final titleController = TextEditingController(text: record?['title'] as String? ?? '');
    final descController = TextEditingController(text: record?['description'] as String? ?? '');
    String selectedType = record?['type'] as String? ?? 'labResults';
    DateTime selectedDate = record?['date'] != null
        ? (DateTime.tryParse(record!['date'] as String) ?? DateTime.now())
        : DateTime.now();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Record' : 'Add Medical Record', style: const TextStyle(fontFamily: 'ClashDisplay')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    prefixIcon: Icon(Icons.title),
                  ),
                  style: const TextStyle(fontFamily: 'Inter'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  style: const TextStyle(fontFamily: 'Inter'),
                  items: const [
                    DropdownMenuItem(value: 'labResults', child: Text('Lab Results')),
                    DropdownMenuItem(value: 'prescriptions', child: Text('Prescriptions')),
                    DropdownMenuItem(value: 'imaging', child: Text('Imaging')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedType = v);
                  },
                ),
                const SizedBox(height: 16),
                // Date picker row
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: Text(
                    '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                    style: const TextStyle(fontFamily: 'Inter'),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                  ),
                  style: const TextStyle(fontFamily: 'Inter'),
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
                      if (titleController.text.trim().isEmpty) return;
                      final user = ref.read(currentUserProvider);
                      if (user == null) return;

                      setDialogState(() => isSaving = true);
                      try {
                        final db = ref.read(databaseServiceProvider);
                        final payload = {
                          'title': titleController.text.trim(),
                          'type': selectedType,
                          'description': descController.text.trim(),
                          'date': selectedDate.toIso8601String().split('T')[0],
                        };
                        if (isEditing && record != null) {
                          await db.updateMedicalRecord(record['id'] as String, payload);
                        } else {
                          payload['user_id'] = user.id;
                          payload['has_attachment'] = false;
                          await db.insertMedicalRecord(payload);
                        }
                        if (mounted) {
                          Navigator.pop(ctx);
                          _loadRecords();
                          AppSnackBar.success(
                            context,
                            isEditing ? 'Record updated!' : 'Record added!',
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          setDialogState(() => isSaving = false);
                          AppSnackBar.errorFromException(
                            context,
                            isEditing ? 'Failed to update record.' : 'Failed to add record.',
                            e,
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary(isDark)),
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(isEditing ? 'Save' : 'Add', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteRecord(Map<String, dynamic> record) async {
    final title = record['title'] as String? ?? 'this record';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Record'),
        content: Text('Are you sure you want to delete "$title"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.urgencyEmergency),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final db = ref.read(databaseServiceProvider);
      await db.deleteMedicalRecord(record['id'] as String);
      _loadRecords();
      if (mounted) AppSnackBar.success(context, 'Record deleted.');
    } catch (e) {
      if (mounted) AppSnackBar.errorFromException(context, 'Failed to delete record.', e);
    }
  }

  void _showRecordMenu(Map<String, dynamic> record) {
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
            ListTile(
              leading: Icon(Icons.edit_outlined, color: AppColors.primary(isDark)),
              title: const Text('Edit Record'),
              onTap: () {
                Navigator.pop(ctx);
                _showEditRecordDialog(record);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.urgencyEmergency),
              title: const Text('Delete Record', style: TextStyle(color: AppColors.urgencyEmergency)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteRecord(record);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredRecords;

    return Scaffold(
      appBar: AppBar(title: const Text('Medical Records')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRecords,
              child: CustomScrollView(
                slivers: [
                  // Search bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search records...',
                          hintStyle: TextStyle(
                            fontFamily: 'Inter',
                            color: AppColors.textHint(isDark),
                          ),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: AppColors.inputFill(isDark),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: const TextStyle(fontFamily: 'Inter'),
                      ),
                    ),
                  ),

                  // Filter chips
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: RecordType.values.map((type) {
                            final isSelected = _selectedFilter == type;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(
                                  _typeLabel(type),
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark ? AppColors.grey300 : AppColors.grey700),
                                  ),
                                ),
                                selected: isSelected,
                                onSelected: (_) => setState(() => _selectedFilter = type),
                                backgroundColor: AppColors.subtleBackground(isDark),
                                selectedColor: AppColors.primary(isDark),
                                checkmarkColor: Colors.white,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),

                  // Records list or empty state
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_open_outlined,
                              size: 64,
                              color: isDark ? AppColors.grey600 : AppColors.grey300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No records found',
                              style: TextStyle(
                                fontFamily: 'ClashDisplay',
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary(isDark),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap + to add a medical record',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: AppColors.textHint(isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final record = filtered[index];
                            final type = record['type'] as String?;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Card(
                                child: ListTile(
                                  leading: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: _typeColor(type).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(_typeIcon(type), color: _typeColor(type), size: 22),
                                  ),
                                  title: Text(
                                    record['title'] ?? 'Untitled',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        record['description'] ?? '',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 13,
                                          color: AppColors.textSecondary(isDark),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatDate(record['date']),
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          color: AppColors.textHint(isDark),
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (record['has_attachment'] == true)
                                        Icon(Icons.attach_file, size: 18, color: AppColors.textSecondary(isDark)),
                                      IconButton(
                                        icon: const Icon(Icons.more_vert, size: 18),
                                        onPressed: () => _showRecordMenu(record),
                                        tooltip: 'More options',
                                      ),
                                    ],
                                  ),
                                  isThreeLine: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  onTap: () => _showEditRecordDialog(record),
                                ),
                              ),
                            );
                          },
                          childCount: filtered.length,
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddRecordDialog,
        backgroundColor: AppColors.primary(isDark),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  String _typeLabel(RecordType type) {
    switch (type) {
      case RecordType.all:
        return 'All';
      case RecordType.labResults:
        return 'Lab Results';
      case RecordType.prescriptions:
        return 'Prescriptions';
      case RecordType.imaging:
        return 'Imaging';
      case RecordType.other:
        return 'Other';
    }
  }
}
