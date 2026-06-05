import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/edge_function_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/loading_overlay.dart';

class TriageScreen extends ConsumerStatefulWidget {
  const TriageScreen({super.key});

  @override
  ConsumerState<TriageScreen> createState() => _TriageScreenState();
}

class _TriageScreenState extends ConsumerState<TriageScreen> {
  final _symptomController = TextEditingController();
  final _notesController = TextEditingController();
  final _durationController = TextEditingController();
  int _severity = 5;
  List<String> _selectedSymptoms = [];
  List<String> _selectedBodyRegions = [];
  bool _isLoading = false;

  final List<String> _commonSymptoms = [
    'Headache', 'Fever', 'Cough', 'Fatigue', 'Nausea',
    'Dizziness', 'Chest Pain', 'Shortness of Breath', 'Sore Throat',
    'Body Aches', 'Loss of Taste', 'Loss of Smell', 'Runny Nose',
    'Stomach Pain', 'Back Pain', 'Joint Pain', 'Rash',
  ];

  final List<String> _bodyRegions = [
    'Head', 'Neck', 'Chest', 'Abdomen', 'Back',
    'Left Arm', 'Right Arm', 'Left Leg', 'Right Leg',
    'Throat', 'Eyes', 'Ears', 'Skin',
  ];

  @override
  void dispose() {
    _symptomController.dispose();
    _notesController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _toggleSymptom(String symptom) {
    setState(() {
      if (_selectedSymptoms.contains(symptom)) {
        _selectedSymptoms.remove(symptom);
      } else {
        _selectedSymptoms.add(symptom);
      }
    });
  }

  void _toggleBodyRegion(String region) {
    setState(() {
      if (_selectedBodyRegions.contains(region)) {
        _selectedBodyRegions.remove(region);
      } else {
        _selectedBodyRegions.add(region);
      }
    });
  }

  Future<void> _runTriage() async {
    if (_selectedSymptoms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one symptom')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final edgeService = EdgeFunctionService();
      final result = await edgeService.runTriage(
        symptoms: _selectedSymptoms,
        severity: _severity,
        duration: _durationController.text.isNotEmpty ? _durationController.text : null,
        bodyRegions: _selectedBodyRegions.isNotEmpty ? _selectedBodyRegions : null,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );
      if (mounted) {
        context.push(AppConfig.triageResult, extra: result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Triage failed: $e'), backgroundColor: AppColors.lightError),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Analyzing symptoms with AI...',
      child: Scaffold(
        appBar: AppBar(title: const Text('Symptom Triage')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // AI Assistant Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.psychology, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'VitalSeker AI',
                            style: TextStyle(
                              fontFamily: 'ClashDisplay',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Describe your symptoms for instant triage',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 24),

              // Symptoms Selection
              Text(
                'Select Symptoms',
                style: TextStyle(
                  fontFamily: 'ClashDisplay',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.lightOnBackground,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _commonSymptoms.map((symptom) {
                  final isSelected = _selectedSymptoms.contains(symptom);
                  return GestureDetector(
                    onTap: () => _toggleSymptom(symptom),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.lightPrimary.withValues(alpha: 0.15)
                            : (isDark ? const Color(0xFF1E2230) : AppColors.grey50),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.lightPrimary
                              : (isDark ? const Color(0xFF2A2F3E) : AppColors.grey200),
                        ),
                      ),
                      child: Text(
                        symptom,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected
                              ? AppColors.lightPrimary
                              : (isDark ? AppColors.grey400 : AppColors.grey600),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Custom Symptom Input
              TextFormField(
                controller: _symptomController,
                decoration: InputDecoration(
                  labelText: 'Add custom symptom',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () {
                      final text = _symptomController.text.trim();
                      if (text.isNotEmpty && !_selectedSymptoms.contains(text)) {
                        setState(() {
                          _selectedSymptoms.add(text);
                          _symptomController.clear();
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Severity Slider
              Text(
                'Severity Level',
                style: TextStyle(
                  fontFamily: 'ClashDisplay',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.lightOnBackground,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('1', style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12, color: isDark ? AppColors.grey500 : AppColors.grey400)),
                  Expanded(
                    child: Slider(
                      value: _severity.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      activeColor: _severityColor(_severity),
                      label: '$_severity',
                      onChanged: (value) => setState(() => _severity = value.round()),
                    ),
                  ),
                  Text('10', style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12, color: isDark ? AppColors.grey500 : AppColors.grey400)),
                ],
              ),
              Center(
                child: Text(
                  '$_severity / 10 - ${_severityLabel(_severity)}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _severityColor(_severity),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Body Regions
              Text(
                'Affected Body Regions',
                style: TextStyle(
                  fontFamily: 'ClashDisplay',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.lightOnBackground,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _bodyRegions.map((region) {
                  final isSelected = _selectedBodyRegions.contains(region);
                  return FilterChip(
                    label: Text(region),
                    selected: isSelected,
                    onSelected: (_) => _toggleBodyRegion(region),
                    selectedColor: AppColors.lightPrimary.withValues(alpha: 0.15),
                    checkmarkColor: AppColors.lightPrimary,
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Duration
              TextFormField(
                controller: _durationController,
                decoration: const InputDecoration(
                  labelText: 'Duration (e.g., 3 days, 2 weeks)',
                  prefixIcon: Icon(Icons.schedule),
                ),
              ),
              const SizedBox(height: 16),

              // Additional Notes
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Additional Notes',
                  prefixIcon: Icon(Icons.note_alt_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 32),

              // Analyze Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _selectedSymptoms.isEmpty ? null : _runTriage,
                  icon: const Icon(Icons.psychology),
                  label: const Text('Analyze with AI'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Color _severityColor(int severity) {
    if (severity <= 3) return AppColors.urgencyLow;
    if (severity <= 6) return AppColors.urgencyMedium;
    if (severity <= 8) return AppColors.urgencyHigh;
    return AppColors.urgencyEmergency;
  }

  String _severityLabel(int severity) {
    if (severity <= 2) return 'Mild';
    if (severity <= 4) return 'Moderate';
    if (severity <= 6) return 'Significant';
    if (severity <= 8) return 'Severe';
    return 'Extreme';
  }
}
