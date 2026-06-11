import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/database_service.dart';
import '../../../shared/theme/app_colors.dart';

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
      final db = DatabaseService();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load records: $e')),
        );
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
        return AppColors.lightInfo;
      case 'prescriptions':
        return isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
      case 'imaging':
        return isDark ? AppColors.darkSecondary : AppColors.lightSecondary;
      default:
        return AppColors.lightWarning;
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
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String selectedType = 'labResults';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Medical Record', style: TextStyle(fontFamily: 'ClashDisplay')),
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                final user = ref.read(currentUserProvider);
                if (user == null) return;

                try {
                  final db = DatabaseService();
                  await db.insertMedicalRecord({
                    'user_id': user.id,
                    'title': titleController.text.trim(),
                    'type': selectedType,
                    'description': descController.text.trim(),
                    'date': DateTime.now().toIso8601String(),
                    'has_attachment': false,
                  });
                  if (mounted) {
                    Navigator.pop(ctx);
                    _loadRecords();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Record added!')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
              child: const Text('Add', style: TextStyle(color: Colors.white)),
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
                            color: isDark ? AppColors.grey500 : AppColors.grey400,
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
                          fillColor: isDark ? AppColors.darkSurface : AppColors.grey50,
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
                                backgroundColor: isDark ? AppColors.darkSurface : AppColors.grey50,
                                selectedColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
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
                                color: isDark ? AppColors.grey400 : AppColors.grey500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap + to add a medical record',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: isDark ? AppColors.grey500 : AppColors.grey400,
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
                                          color: isDark ? AppColors.grey400 : AppColors.grey500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatDate(record['date']),
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          color: isDark ? AppColors.grey500 : AppColors.grey400,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: record['has_attachment'] == true
                                      ? Icon(Icons.attach_file, size: 18, color: isDark ? AppColors.grey400 : AppColors.grey500)
                                      : null,
                                  isThreeLine: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
        backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
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
