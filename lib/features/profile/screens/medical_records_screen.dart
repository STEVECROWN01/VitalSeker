import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/widgets/medical_disclaimer_banner.dart';
import '../../../shared/widgets/pro_feature_gate.dart';
import '../../../core/providers/subscription_provider.dart';

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
    if (user == null) {
      // Avoid infinite spinner if user is somehow null (signed out mid-screen).
      if (mounted) setState(() => _isLoading = false);
      return;
    }
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
        AppSnackBar.errorFromException(context, AppLocalizations.of(context)!.recordsLoadFailed, e);
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
    if (dateStr == null) return AppLocalizations.of(context)!.notAvailable;
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
    final l10n = AppLocalizations.of(context)!;
    final isEditing = record != null;
    final titleController = TextEditingController(text: record?['title'] as String? ?? '');
    final descController = TextEditingController(text: record?['description'] as String? ?? '');
    String selectedType = record?['type'] as String? ?? 'labResults';
    DateTime selectedDate = record?['date'] != null
        ? (DateTime.tryParse(record!['date'] as String) ?? DateTime.now())
        : DateTime.now();
    bool isSaving = false;
    File? attachedFile;
    String? attachedFileName;
    String? existingFileUrl;
    bool isUploading = false;

    // If editing, check for existing file URL
    if (isEditing) {
      existingFileUrl = record['attachment_url'] as String?;
      // Try to extract the file name from the URL
      if (existingFileUrl != null) {
        final uri = Uri.tryParse(existingFileUrl);
        if (uri != null) {
          final pathSegments = uri.pathSegments;
          if (pathSegments.isNotEmpty) {
            attachedFileName = pathSegments.last.split('_').last;
          }
        }
        attachedFileName ??= 'Attached document';
      }
    }

    /// Verify the file type by reading magic bytes.
    String? _verifyFileType(File file) {
      try {
        final bytes = file.readAsBytesSync();
        if (bytes.length < 4) return null;
        if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return 'image/jpeg';
        if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return 'image/png';
        if (bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46) return 'application/pdf';
        if (bytes.length >= 8 && bytes[0] == 0xD0 && bytes[1] == 0xCF && bytes[2] == 0x11 && bytes[3] == 0xE0 && bytes[4] == 0xA1 && bytes[5] == 0xB1 && bytes[6] == 0x1A && bytes[7] == 0xE1) return 'application/msword';
        if (bytes[0] == 0x50 && bytes[1] == 0x4B && bytes[2] == 0x03 && bytes[3] == 0x04) return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
        return null;
      } catch (e) {
        debugPrint('File type verification failed: $e');
        return null;
      }
    }

    Future<String?> _uploadFile(File file, String userId) async {
      try {
        final fileSize = file.lengthSync();
        const maxSize = 10 * 1024 * 1024; // 10 MB
        if (fileSize > maxSize) {
          if (mounted) {
            AppSnackBar.error(
              context,
              'File is too large (${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB). '
              'Maximum allowed size is 10 MB.',
            );
          }
          return null;
        }

        // SECURITY FIX (audit H-29): verify the actual file type by reading
        // magic bytes, not just the file extension. A user can rename
        // malware.exe → report.pdf and the FilePicker extension filter
        // would accept it. We read the first few bytes and compare against
        // known magic numbers for allowed types.
        final allowedMime = _verifyFileType(file);
        if (allowedMime == null) {
          if (mounted) {
            AppSnackBar.error(
              context,
              'File type not allowed. Please upload a JPG, PNG, PDF, DOC, or DOCX file.',
            );
          }
          return null;
        }

        final fileName = '${userId}/${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
        final storage = Supabase.instance.client.storage;

        // Upload to the 'medical-records' bucket with the verified MIME type.
        // The bucket's allowed_mime_types policy (migration 010) will also
        // enforce this server-side as defense-in-depth.
        await storage.from('medical-records').upload(
          fileName,
          file,
          fileOptions: FileOptions(contentType: allowedMime),
        );

        return 'medical-records://$fileName';
      } catch (e) {
        debugPrint('File upload error: $e');
        if (mounted) {
          AppSnackBar.error(
            context,
            'Could not upload file. Please check your connection and try again.',
          );
        }
        return null;
      }
    }

    Future<void> _pickFromCamera(void Function(void Function()) setDialogState) async {
      try {
        final picker = ImagePicker();
        final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
        if (picked == null) return;

        // Try cropping with safe fallback — if cropper crashes, use the raw image
        String imagePath = picked.path;
        try {
          final cropped = await ImageCropper().cropImage(
            sourcePath: picked.path,
            uiSettings: [
              AndroidUiSettings(
                toolbarTitle: 'Crop Document',
                toolbarColor: AppColors.darkPrimary,
                toolbarWidgetColor: Colors.white,
                activeControlsWidgetColor: Colors.white,
                lockAspectRatio: false,
                aspectRatioPresets: [
                  CropAspectRatioPreset.original,
                  CropAspectRatioPreset.square,
                  CropAspectRatioPreset.ratio3x2,
                  CropAspectRatioPreset.ratio4x3,
                  CropAspectRatioPreset.ratio16x9,
                ],
              ),
              IOSUiSettings(
                title: 'Crop Document',
                aspectRatioLockEnabled: false,
                aspectRatioPresets: [
                  CropAspectRatioPreset.original,
                  CropAspectRatioPreset.square,
                  CropAspectRatioPreset.ratio3x2,
                  CropAspectRatioPreset.ratio4x3,
                  CropAspectRatioPreset.ratio16x9,
                ],
              ),
            ],
          );
          if (cropped != null) {
            imagePath = cropped.path;
          }
        } catch (cropError) {
          // Cropper failed — use the raw image (no crash)
          debugPrint('Crop failed, using raw image: $cropError');
        }

        setDialogState(() {
          attachedFile = File(imagePath);
          attachedFileName = 'Scanned document';
          isUploading = true;
        });

        // Upload to Supabase Storage.
        // SECURITY FIX (audit C-11): only show "scanned successfully" if the
        // upload actually succeeded. The previous code showed success even
        // when _uploadFile returned null (upload failed), leaving the user
        // with a false sense that the file was attached.
        final user = ref.read(currentUserProvider);
        if (user != null) {
          final url = await _uploadFile(File(imagePath), user.id);
          if (url != null) {
            existingFileUrl = url;
            if (mounted) {
              AppSnackBar.success(context, 'Document scanned and uploaded successfully');
            }
          } else {
            // Upload failed — _uploadFile already showed an error snackbar.
            // Reset the attachment state so the user doesn't see a phantom file.
            setDialogState(() {
              attachedFile = null;
              attachedFileName = null;
            });
          }
        }

        setDialogState(() => isUploading = false);
      } catch (e) {
        setDialogState(() => isUploading = false);
        if (mounted) {
          AppSnackBar.error(context, 'Could not capture document: $e');
        }
      }
    }

    Future<void> _pickFromFile(void Function(void Function()) setDialogState) async {
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
        );
        if (result == null || result.files.single.path == null) return;

        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;

        setDialogState(() {
          attachedFile = file;
          attachedFileName = fileName;
          isUploading = true;
        });

        // Upload to Supabase Storage.
        // SECURITY FIX (audit C-11): only show "uploaded successfully" if the
        // upload actually succeeded. _uploadFile shows its own error snackbar
        // on failure, so we just reset the attachment state here.
        final user = ref.read(currentUserProvider);
        if (user != null) {
          final url = await _uploadFile(file, user.id);
          if (url != null) {
            existingFileUrl = url;
            if (mounted) {
              AppSnackBar.success(context, 'File uploaded successfully');
            }
          } else {
            // Upload failed — reset the attachment state.
            setDialogState(() {
              attachedFile = null;
              attachedFileName = null;
            });
          }
        }

        setDialogState(() => isUploading = false);
      } catch (e) {
        setDialogState(() => isUploading = false);
        if (mounted) {
          AppSnackBar.error(context, 'Could not pick file: $e');
        }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEditing ? l10n.editRecordTitle : l10n.addMedicalRecordTitle, style: const TextStyle(fontFamily: 'ClashDisplay')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: l10n.titleLabel,
                    prefixIcon: const Icon(Icons.title),
                  ),
                  style: const TextStyle(fontFamily: 'Inter'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  dropdownColor: AppColors.surface(isDark),
                  style: TextStyle(color: AppColors.textPrimary(isDark)),
                  value: selectedType,
                  decoration: InputDecoration(
                    labelText: l10n.typeLabel,
                    prefixIcon: const Icon(Icons.category_outlined),
                  ),
                  items: [
                    DropdownMenuItem(value: 'labResults', child: Text(l10n.recordTypeLabResults)),
                    DropdownMenuItem(value: 'prescriptions', child: Text(l10n.recordTypePrescriptions)),
                    DropdownMenuItem(value: 'imaging', child: Text(l10n.recordTypeImaging)),
                    DropdownMenuItem(value: 'other', child: Text(l10n.recordTypeOther)),
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
                  decoration: InputDecoration(
                    labelText: l10n.descriptionLabel,
                    alignLabelWithHint: true,
                  ),
                  style: const TextStyle(fontFamily: 'Inter'),
                ),
                const SizedBox(height: 16),
                // File upload section — optional attachment
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Attachment (optional)',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary(isDark),
                        ),
                      ),
                    ),
                    if (isUploading)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // Show attached file or upload buttons
                if (attachedFile != null || existingFileUrl != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer(isDark),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border(isDark)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.attach_file, color: AppColors.primary(isDark), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            attachedFileName ?? 'Existing file',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary(isDark),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, size: 18, color: AppColors.error(isDark)),
                          onPressed: isUploading ? null : () {
                            setDialogState(() {
                              attachedFile = null;
                              attachedFileName = null;
                              existingFileUrl = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isUploading ? null : () => _pickFromCamera(setDialogState),
                          icon: const Icon(Icons.camera_alt_outlined, size: 18),
                          label: const Text('Scan'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary(isDark),
                            side: BorderSide(color: AppColors.primary(isDark)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isUploading ? null : () => _pickFromFile(setDialogState),
                          icon: const Icon(Icons.folder_outlined, size: 18),
                          label: const Text('Upload'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary(isDark),
                            side: BorderSide(color: AppColors.primary(isDark)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (titleController.text.trim().isEmpty) {
                        AppSnackBar.error(context, l10n.fieldRequired);
                        return;
                      }
                      final user = ref.read(currentUserProvider);
                      if (user == null) return;

                      setDialogState(() => isSaving = true);
                      try {
                        final db = ref.read(databaseServiceProvider);
                        final payload = <String, dynamic>{
                          'title': titleController.text.trim(),
                          'type': selectedType,
                          'description': descController.text.trim(),
                          'date': selectedDate.toIso8601String().split('T')[0],
                        };
                        // Only include attachment_url if we have a file
                        if (existingFileUrl != null) {
                          payload['attachment_url'] = existingFileUrl;
                        }
                        if (isEditing) {
                          await db.updateMedicalRecord(record['id'] as String, payload);
                        } else {
                          payload['user_id'] = user.id;
                          await db.insertMedicalRecord(payload);
                        }
                        if (mounted) {
                          Navigator.pop(ctx);
                          _loadRecords();
                          AppSnackBar.success(
                            context,
                            isEditing ? l10n.recordUpdated : l10n.recordAdded,
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          setDialogState(() => isSaving = false);
                          AppSnackBar.errorFromException(
                            context,
                            isEditing ? l10n.recordUpdateFailed : l10n.recordAddFailed,
                            e,
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary(isDark)),
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(isEditing ? l10n.save : l10n.add, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
      // FIX: dispose the controllers when the dialog closes to prevent
      // memory leak (every open of this dialog previously leaked 2
      // TextEditingControllers).
    ).then((_) {
      titleController.dispose();
      descController.dispose();
    });
  }

  Future<void> _deleteRecord(Map<String, dynamic> record) async {
    final l10n = AppLocalizations.of(context)!;
    final title = record['title'] as String? ?? 'this record';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteRecordTitle),
        content: Text(l10n.deleteRecordConfirm(title)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.urgencyEmergency),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final db = ref.read(databaseServiceProvider);
      await db.deleteMedicalRecord(record['id'] as String);
      _loadRecords();
      if (mounted) AppSnackBar.success(context, l10n.recordDeleted);
    } catch (e) {
      if (mounted) AppSnackBar.errorFromException(context, l10n.recordDeleteFailed, e);
    }
  }

  void _showRecordMenu(Map<String, dynamic> record) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
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
              title: Text(l10n.editRecordTitle),
              onTap: () {
                Navigator.pop(ctx);
                _showEditRecordDialog(record);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.urgencyEmergency),
              title: Text(l10n.deleteRecordTitle, style: const TextStyle(color: AppColors.urgencyEmergency)),
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
    final isPro = ref.watch(isProUserProvider);

    if (!isPro) {
      return const ProFeatureGate(
        featureName: 'Medical Records',
        featureDescription: 'Store and manage your prescriptions, lab results, and imaging files securely. Scan documents with your camera and access them anytime.',
        featureIcon: Icons.folder_outlined,
      );
    }

    final l10n = AppLocalizations.of(context)!;
    final filtered = _filteredRecords;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.medicalRecordsTitle)),
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
                          hintText: l10n.searchRecordsHint,
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
                              l10n.noRecordsFound,
                              style: TextStyle(
                                fontFamily: 'ClashDisplay',
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary(isDark),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.tapToAddRecord,
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
                                    record['title'] ?? l10n.untitled,
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
                                      if (record['attachment_url'] != null)
                                        Icon(Icons.attach_file, size: 18, color: AppColors.textSecondary(isDark)),
                                      IconButton(
                                        icon: const Icon(Icons.more_vert, size: 18),
                                        onPressed: () => _showRecordMenu(record),
                                        tooltip: l10n.moreOptions,
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

                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: MedicalDisclaimerBanner(compact: true),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
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
    final l10n = AppLocalizations.of(context)!;
    switch (type) {
      case RecordType.all:
        return l10n.all;
      case RecordType.labResults:
        return l10n.recordTypeLabResults;
      case RecordType.prescriptions:
        return l10n.recordTypePrescriptions;
      case RecordType.imaging:
        return l10n.recordTypeImaging;
      case RecordType.other:
        return l10n.recordTypeOther;
    }
  }
}
