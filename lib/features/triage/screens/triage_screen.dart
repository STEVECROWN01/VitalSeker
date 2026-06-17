import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/edge_function_service.dart';
import '../../../shared/theme/app_colors.dart';

class TriageScreen extends ConsumerStatefulWidget {
  const TriageScreen({super.key});

  @override
  ConsumerState<TriageScreen> createState() => _TriageScreenState();
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final Map<String, dynamic>? triageResult;
  final bool isTyping;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.triageResult,
    this.isTyping = false,
  });
}

class _TriageScreenState extends ConsumerState<TriageScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isProcessing = false;
  Map<String, dynamic>? _lastTriageResult;

  /// Rolling window of past turns sent to the edge function on each new
  /// message so Claude has conversation context. Capped at the last 5 turns
  /// (10 messages max) to bound token usage.
  static const int _maxHistoryTurns = 5;
  final List<Map<String, String>> _conversationHistory = [];

  @override
  void initState() {
    super.initState();
    // Add initial AI greeting after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addAiMessage('Hello! I\'m VitalSeker AI. How are you feeling today? Describe your symptoms and I\'ll help assess your condition.');
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addAiMessage(String text, {Map<String, dynamic>? triageResult}) {
    setState(() {
      _messages.add(_ChatMessage(
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
        triageResult: triageResult,
      ));
    });
    // Only track turns that have meaningful text (skip empty / typing bubbles)
    // AND that contain a triage result — those are the "real" AI responses
    // worth remembering for context. Pure conversational AI text (greeting,
    // error) is also tracked so follow-up questions make sense.
    if (text.isNotEmpty) {
      _conversationHistory.add({'role': 'assistant', 'content': text});
      _trimHistory();
    }
    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add(_ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
    });
    if (text.isNotEmpty) {
      _conversationHistory.add({'role': 'user', 'content': text});
      _trimHistory();
    }
    _scrollToBottom();
  }

  void _trimHistory() {
    // Keep the last _maxHistoryTurns turns (1 turn = 1 user + 1 assistant msg).
    while (_conversationHistory.length > _maxHistoryTurns * 2) {
      _conversationHistory.removeAt(0);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isProcessing) return;

    _messageController.clear();
    _addUserMessage(text);

    setState(() => _isProcessing = true);

    // Show typing indicator
    setState(() {
      _messages.add(_ChatMessage(
        text: '',
        isUser: false,
        timestamp: DateTime.now(),
        isTyping: true,
      ));
    });
    _scrollToBottom();

    try {
      final edgeService = EdgeFunctionService();
      // Parse symptoms from user message
      final symptoms = _parseSymptoms(text);
      final severity = _inferSeverity(text);

      // Pass the conversation history (last 5 turns) so follow-up questions
      // like "is that why I've been dizzy?" actually work as a conversation.
      // Send a defensive copy so the edge function can't mutate our list.
      final historyToSend = List<Map<String, String>>.from(_conversationHistory);

      final result = await edgeService.runTriage(
        symptoms: symptoms,
        severity: severity,
        notes: text,
        conversationHistory: historyToSend,
      );

      _lastTriageResult = result;

      // Remove typing indicator
      setState(() {
        _messages.removeWhere((m) => m.isTyping);
      });

      // Build AI response from triage result
      final triage = result['triage'] as Map<String, dynamic>? ?? result;
      final urgencyLevel = triage['urgency_level'] as String? ?? 'medium';
      final urgencyScore = triage['urgency_score'] as int? ?? 50;
      final seekCare = triage['seek_care'] as String? ?? '';
      final recommendations = (triage['recommendations'] as List<dynamic>? ?? []).cast<String>();
      final redFlags = (triage['red_flags'] as List<dynamic>? ?? []).cast<String>();

      final responseBuffer = StringBuffer();
      responseBuffer.writeln('Based on your symptoms, here\'s my assessment:');
      responseBuffer.writeln();
      responseBuffer.writeln('Urgency: ${urgencyLevel.toUpperCase()} ($urgencyScore/100)');

      if (seekCare.isNotEmpty) {
        responseBuffer.writeln('Care recommendation: ${_seekCareLabel(seekCare)}');
      }

      if (redFlags.isNotEmpty) {
        responseBuffer.writeln();
        responseBuffer.writeln('⚠️ Red flags:');
        for (final flag in redFlags.take(3)) {
          responseBuffer.writeln('• $flag');
        }
      }

      if (recommendations.isNotEmpty) {
        responseBuffer.writeln();
        responseBuffer.writeln('Recommendations:');
        for (final rec in recommendations.take(3)) {
          responseBuffer.writeln('• $rec');
        }
      }

      responseBuffer.writeln();
      responseBuffer.writeln('Tap "View Detailed Results" below for the full analysis.');

      _addAiMessage(
        responseBuffer.toString(),
        triageResult: result,
      );
    } catch (e) {
      // Remove typing indicator
      setState(() {
        _messages.removeWhere((m) => m.isTyping);
      });

      _addAiMessage(
        'I\'m sorry, I encountered an error analyzing your symptoms. Please try again or describe your symptoms differently.\n\nError: $e',
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  List<String> _parseSymptoms(String text) {
    final commonSymptoms = [
      'headache', 'fever', 'cough', 'fatigue', 'nausea',
      'dizziness', 'chest pain', 'shortness of breath', 'sore throat',
      'body aches', 'loss of taste', 'loss of smell', 'runny nose',
      'stomach pain', 'back pain', 'joint pain', 'rash',
      'vomiting', 'diarrhea', 'chills', 'sweating', 'bleeding',
    ];

    final lower = text.toLowerCase();
    final found = <String>[];
    for (final s in commonSymptoms) {
      if (lower.contains(s)) {
        found.add(s.split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' '));
      }
    }

    // If no known symptoms matched, use the whole message as a custom symptom
    if (found.isEmpty && text.length > 2) {
      found.add(text.length > 50 ? '${text.substring(0, 50)}...' : text);
    }

    return found.isNotEmpty ? found : ['General discomfort'];
  }

  int _inferSeverity(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('severe') || lower.contains('extreme') || lower.contains('unbearable')) return 9;
    if (lower.contains('very bad') || lower.contains('intense') || lower.contains('awful')) return 8;
    if (lower.contains('bad') || lower.contains('painful') || lower.contains('worse')) return 7;
    if (lower.contains('moderate') || lower.contains('uncomfortable')) return 5;
    if (lower.contains('mild') || lower.contains('slight') || lower.contains('minor')) return 3;
    return 5;
  }

  void _startNewChat() {
    setState(() {
      _messages.clear();
      _conversationHistory.clear();
      _lastTriageResult = null;
      _isProcessing = false;
    });
    _addAiMessage('Hello! I\'m VitalSeker AI. How are you feeling today? Describe your symptoms and I\'ll help assess your condition.');
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

  String _seekCareLabel(String care) {
    switch (care) {
      case 'self-care': return 'Self-Care Recommended';
      case 'schedule-appointment': return 'Schedule an Appointment';
      case 'urgent-care': return 'Visit Urgent Care';
      case 'emergency': return 'Seek Emergency Care';
      default: return 'Consult a Healthcare Provider';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.psychology, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('AI Triage'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'New Chat',
            onPressed: _startNewChat,
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _ChatBubble(
                  message: message,
                  isDark: isDark,
                  onViewResults: message.triageResult != null
                      ? () => context.push(
                            AppConfig.triageResult,
                            extra: message.triageResult,
                          )
                      : null,
                );
              },
            ),
          ),

          // Bottom input bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface(isDark),
              border: Border(
                top: BorderSide(
                  color: AppColors.border(isDark),
                ),
              ),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      enabled: !_isProcessing,
                      decoration: InputDecoration(
                        hintText: 'Describe your symptoms...',
                        hintStyle: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: AppColors.textHint(isDark),
                        ),
                        filled: true,
                        fillColor: AppColors.inputFill(isDark),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: (AppColors.primary(isDark)).withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: AppColors.textPrimary(isDark),
                      ),
                      maxLines: 4,
                      minLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: _isProcessing
                          ? null
                          : AppColors.brandGradient,
                      color: _isProcessing
                          ? (isDark ? AppColors.grey700 : AppColors.grey300)
                          : null,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _isProcessing ? null : _sendMessage,
                      icon: _isProcessing
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textSecondary(isDark),
                              ),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;
  final bool isDark;
  final VoidCallback? onViewResults;

  const _ChatBubble({
    required this.message,
    required this.isDark,
    this.onViewResults,
  });

  @override
  Widget build(BuildContext context) {
    // Typing indicator
    if (message.isTyping) {
      return _TypingIndicator(isDark: isDark);
    }

    final isUser = message.isUser;

    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 48 : 0,
        right: isUser ? 0 : 48,
        bottom: 12,
      ),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.psychology, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? (AppColors.primary(isDark))
                        : (AppColors.subtleBackground(isDark)),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    border: isUser
                        ? null
                        : Border.all(
                            color: AppColors.border(isDark),
                          ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        message.text,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          height: 1.5,
                          color: isUser
                              ? Colors.white
                              : (AppColors.onBackground(isDark)),
                        ),
                      ),
                      // View detailed results button
                      if (message.triageResult != null && onViewResults != null) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: onViewResults,
                            icon: const Icon(Icons.open_in_new_rounded, size: 16),
                            label: const Text('View Detailed Results'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isUser
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : (AppColors.primary(isDark)),
                              foregroundColor: isUser
                                  ? Colors.white
                                  : Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      color: AppColors.textTertiary(isDark),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: (AppColors.primary(isDark)).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.person, color: AppColors.primary(isDark), size: 16),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.05, end: 0);
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _TypingIndicator extends StatefulWidget {
  final bool isDark;
  const _TypingIndicator({required this.isDark});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.psychology, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.subtleBackground(widget.isDark),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(
                color: AppColors.border(widget.isDark),
              ),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (index) {
                    final progress = (_controller.value * 3 - index) % 1.0;
                    final scale = progress < 0.5
                        ? 0.5 + progress
                        : 1.5 - progress;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Transform.scale(
                        scale: scale.clamp(0.5, 1.2),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: (AppColors.primary(widget.isDark))
                                .withValues(alpha: 0.6 + (scale - 0.5) * 0.4),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
