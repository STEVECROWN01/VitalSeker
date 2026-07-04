import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_snack_bar.dart';

/// AI Chat Triage Screen — "CK" the AI Health Assistant
///
/// A conversational AI chat (like ChatGPT but for health).
/// The user can type or hold-to-record voice notes.
/// Voice notes are transcribed in real-time and sent to the AI.
///
/// The AI:
///   - Asks questions to understand symptoms
///   - Manages user stress/emotions with empathy
///   - Provides general health advice (not diagnoses)
///   - Always recommends seeing a doctor
class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;

  _ChatMessage({
    required this.content,
    required this.isUser,
    required this.timestamp,
  });
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isSending = false;
  bool _isRecording = false;
  String _partialTranscription = '';

  @override
  void initState() {
    super.initState();
    // Add CK's greeting message
    final l10n = AppLocalizations.of(context)!;
    _messages.add(_ChatMessage(
      content: l10n.ckGreeting,
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    _textController.clear();
    setState(() {
      _messages.add(_ChatMessage(
        content: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final response = await SupabaseService().client.functions.invoke(
        'ai-chat',
        body: {
          'messages': _messages
              .map((m) => {
                    'role': m.isUser ? 'user' : 'assistant',
                    'content': m.content,
                  })
              .toList(),
          'language': Localizations.localeOf(context).languageCode,
        },
      ).timeout(const Duration(seconds: 60));

      final data = response.data as Map<String, dynamic>;
      final reply = data['reply'] as String? ??
          "I'm sorry, I didn't catch that. Could you tell me more?";

      setState(() {
        _messages.add(_ChatMessage(
          content: reply,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(
          content:
              "I'm having trouble connecting right now. Please try again. If this is an emergency, call 112 or 911.",
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isSending = false;
      });
      _scrollToBottom();
    }
  }

  void _startRecording() {
    // Voice recording would use the speech_to_text or record package
    // For now, show a placeholder that voice notes require the package
    setState(() {
      _isRecording = true;
      _partialTranscription = '';
    });
    AppSnackBar.info(
      context,
      'Voice notes require the speech_to_text package. Please type your message for now.',
    );
  }

  void _stopRecording() {
    setState(() {
      _isRecording = false;
      if (_partialTranscription.isNotEmpty) {
        _textController.text = _partialTranscription;
      }
      _partialTranscription = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradientFor(isDark),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'CK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CK — AI Health Assistant',
                    style: AppTextStyles.subheading2.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _isSending ? 'typing...' : 'Online',
                    style: TextStyle(
                      fontSize: 11,
                      color: _isSending
                          ? AppColors.textSecondary(isDark)
                          : AppColors.success(isDark),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go(AppConfig.dashboard);
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _shareConversation,
            tooltip: 'Share conversation',
          ),
        ],
      ),
      body: Column(
        children: [
          // Medical disclaimer banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.warning(isDark).withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: AppColors.warning(isDark)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.medicalDisclaimerShort,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _ChatBubble(
                  message: msg,
                  isDark: isDark,
                );
              },
            ),
          ),
          // Loading indicator
          if (_isSending)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(width: 20),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface(isDark),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary(isDark),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'CK is thinking...',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          // Input bar
          _buildInputBar(isDark, l10n),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isDark, AppLocalizations l10n) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          border: Border(
            top: BorderSide(color: AppColors.border(isDark), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Voice record button
            GestureDetector(
              onLongPressStart: (_) => _startRecording(),
              onLongPressEnd: (_) => _stopRecording(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _isRecording
                      ? AppColors.error(isDark)
                      : AppColors.primaryContainer(isDark),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isRecording ? Icons.stop : Icons.mic,
                  color: _isRecording
                      ? Colors.white
                      : AppColors.primary(isDark),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Text input
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.inputFill(isDark),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _textController,
                  maxLines: 5,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: _isRecording
                        ? 'Recording...'
                        : 'Type your message...',
                    hintStyle: TextStyle(
                      color: AppColors.textHint(isDark),
                      fontSize: 14,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: InputBorder.none,
                  ),
                  style: TextStyle(
                    color: AppColors.textPrimary(isDark),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send button
            GestureDetector(
              onTap: _isSending ? null : _sendMessage,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _isSending
                      ? AppColors.outlineVariant(isDark)
                      : AppColors.primary(isDark),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.send,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shareConversation() {
    final conversationText = _messages.map((m) {
      final sender = m.isUser ? 'You' : 'CK';
      return '[$sender] ${m.content}';
    }).join('\n\n');

    Share.share(
      'My VitalSeker AI Health Chat with CK:\n\n$conversationText\n\n— Shared via VitalSeker',
      subject: 'VitalSeker AI Health Chat',
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;
  final bool isDark;

  const _ChatBubble({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.80,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? AppColors.primary(isDark)
              : AppColors.surface(isDark),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser
                ? const Radius.circular(16)
                : const Radius.circular(4),
            bottomRight: isUser
                ? const Radius.circular(4)
                : const Radius.circular(16),
          ),
          border: isUser
              ? null
              : Border.all(color: AppColors.border(isDark), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'CK',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary(isDark),
                  ),
                ),
              ),
            Text(
              message.content,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: isUser
                    ? Colors.white
                    : AppColors.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 9,
                color: isUser
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppColors.textHint(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
