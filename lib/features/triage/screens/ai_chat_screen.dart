import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:file_picker/file_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/providers/health_passport_provider.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_snack_bar.dart';

/// AI Chat Screen — "Seker" the AI Health Assistant
///
/// A conversational AI health chat. The user can type or hold-to-record
/// voice notes. Voice notes are transcribed in real-time and sent to the AI.
///
/// Seker:
///   - Introduces itself on first message + tells user what it knows about them
///   - Asks questions to understand symptoms
///   - Manages user stress/emotions with empathy
///   - Provides general health advice (not diagnoses)
///   - Always recommends consulting a professional doctor
///   - Responds in the user's language (40 supported languages)
///   - ONLY discusses health/biology/psychology
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
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initConnectivity();
    // Add Seker's greeting message
    final l10n = AppLocalizations.of(context)!;
    _messages.add(_ChatMessage(
      content: l10n.sekerGreeting,
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _initConnectivity() async {
    try {
      final connectivity = Connectivity();
      // Check initial connectivity
      final result = await connectivity.checkConnectivity();
      if (mounted) {
        setState(() {
          _isOnline = !result.contains(ConnectivityResult.none);
        });
      }
      // Listen for connectivity changes
      _connectivitySubscription = connectivity.onConnectivityChanged.listen((result) {
        if (mounted) {
          setState(() {
            _isOnline = !result.contains(ConnectivityResult.none);
          });
        }
      });
    } catch (e) {
      debugPrint('Connectivity init failed: $e');
    }
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onError: (error) => debugPrint('Speech error: $error'),
        onStatus: (status) {
          if (status == 'notListening' && _isRecording) {
            _stopRecording();
          }
        },
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Speech init failed: $e');
      _speechAvailable = false;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _speech.stop();
    _connectivitySubscription?.cancel();
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

    // Block sending when offline — AI requires internet
    if (!_isOnline) {
      AppSnackBar.error(
        context,
        'You are offline. Seker AI requires an internet connection. Please connect to a network to chat.',
      );
      return;
    }

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
              .where((m) => m.isUser || m.content != (AppLocalizations.of(context)?.sekerGreeting ?? ''))
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

      // Check if Seker auto-saved any health data from the conversation
      final savedData = (data['saved_data'] as List<dynamic>?) ?? [];
      if (savedData.isNotEmpty) {
        // Show a subtle success notification
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            AppSnackBar.success(
              context,
              '✓ ${savedData.join(', ')} saved to your profile',
            );
            // Invalidate providers so the profile/passport refresh
            ref.invalidate(userProfileProvider);
            ref.invalidate(healthPassportProvider);
          }
        });
      }

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

  Future<void> _startRecording() async {
    if (!_speechAvailable) {
      AppSnackBar.error(
        context,
        'Speech recognition is not available on this device. Please type your message.',
      );
      return;
    }

    try {
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _partialTranscription = result.recognizedWords;
            _textController.text = _partialTranscription;
            _textController.selection = TextSelection.fromPosition(
              TextPosition(offset: _textController.text.length),
            );
          });
        },
        localeId: Localizations.localeOf(context).languageCode,
        listenMode: stt.ListenMode.dictation,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 5),
      );
      setState(() {
        _isRecording = true;
        _partialTranscription = '';
      });
    } catch (e) {
      AppSnackBar.error(
        context,
        'Could not start voice recording. Please check microphone permissions.',
      );
    }
  }

  Future<void> _stopRecording() async {
    await _speech.stop();
    setState(() {
      _isRecording = false;
      if (_partialTranscription.isNotEmpty) {
        _textController.text = _partialTranscription;
      }
      _partialTranscription = '';
    });
  }

  /// Pick a file (prescription, lab result, imaging) to share with Seker.
  /// The file name is inserted into the chat as a user message so Seker
  /// knows the user has shared a document.
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
      );
      if (result == null || result.files.single.path == null) return;

      final fileName = result.files.single.name;
      final file = File(result.files.single.path!);

      // Upload to Supabase Storage
      final user = ref.read(currentUserProvider);
      if (user == null) {
        AppSnackBar.error(context, 'Please sign in to upload files.');
        return;
      }

      AppSnackBar.info(context, 'Uploading $fileName...');

      final storagePath = '${user.id}/chat/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      try {
        await Supabase.instance.client.storage
            .from('medical-records')
            .upload(storagePath, file);
      } catch (e) {
        // If storage fails, still send the message to Seker about the file
        debugPrint('Storage upload failed: $e');
      }

      // Add a message to the chat indicating the user shared a file
      final fileMessage = 'I\'ve shared a file: $fileName. Please analyze this and let me know what you think.';
      _textController.text = fileMessage;
      await _sendMessage();
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'Could not pick file: $e');
      }
    }
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
            // Seker AI avatar — clean, fully visible
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                'assets/images/branding/seker_ai_avatar.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seker AI',
                    style: AppTextStyles.subheading2.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Row(
                    children: [
                      // Online/offline status indicator
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isOnline
                              ? AppColors.success(isDark)
                              : AppColors.error(isDark),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (_isOnline
                                      ? AppColors.success(isDark)
                                      : AppColors.error(isDark))
                                  .withValues(alpha: 0.5),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isSending
                            ? 'typing...'
                            : (_isOnline ? 'Online' : 'Offline'),
                        style: TextStyle(
                          fontSize: 11,
                          color: _isSending
                              ? AppColors.textSecondary(isDark)
                              : (_isOnline
                                  ? AppColors.success(isDark)
                                  : AppColors.error(isDark)),
                        ),
                      ),
                    ],
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Three glowing animated dots (like ChatGPT typing indicator)
                        _TypingDots(isDark: isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          // Recording indicator
          if (_isRecording)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.error(isDark).withValues(alpha: 0.1),
              child: Row(
                children: [
                  // Pulsing mic icon
                  _PulsingMicIcon(color: AppColors.error(isDark)),
                  const SizedBox(width: 8),
                  // Animated waveform-style bars (not transcription text)
                  _RecordingWaveform(isDark: isDark),
                  const Spacer(),
                  GestureDetector(
                    onTap: _stopRecording,
                    child: Text(
                      'Stop',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error(isDark),
                      ),
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
            // File upload button — share prescriptions, lab results, etc.
            GestureDetector(
              onTap: _pickFile,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer(isDark),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.attach_file,
                  color: AppColors.primary(isDark),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Voice record button — tap to start, tap again to stop
            GestureDetector(
              onTap: _isRecording ? _stopRecording : _startRecording,
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
                        : 'Type or tap mic to speak...',
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
      final sender = m.isUser ? 'You' : 'Seker';
      return '[$sender] ${m.content}';
    }).join('\n\n');

    Share.share(
      'My VitalSeker AI Health Chat with Seker:\n\n$conversationText\n\n— Shared via VitalSeker',
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/images/branding/seker_ai_avatar.png',
                        width: 18,
                        height: 18,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Seker',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary(isDark),
                      ),
                    ),
                  ],
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

/// Three glowing animated dots — typing indicator like ChatGPT/WhatsApp.
/// Each dot pulses with a staggered delay, creating a "typing" animation.
class _TypingDots extends StatefulWidget {
  final bool isDark;
  const _TypingDots({required this.isDark});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      final c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) c.repeat(reverse: true);
      });
      return c;
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.primary(widget.isDark);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _controllers[i],
          builder: (context, child) {
            final scale = 0.5 + _controllers[i].value * 0.5;
            final opacity = 0.3 + _controllers[i].value * 0.7;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: opacity),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

/// Pulsing microphone icon — scales in/out to show recording is active.
class _PulsingMicIcon extends StatefulWidget {
  final Color color;
  const _PulsingMicIcon({required this.color});

  @override
  State<_PulsingMicIcon> createState() => _PulsingMicIconState();
}

class _PulsingMicIconState extends State<_PulsingMicIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + _controller.value * 0.4,
          child: Icon(Icons.mic, color: widget.color, size: 16),
        );
      },
    );
  }
}

/// Animated waveform bars — like WhatsApp voice note recording indicator.
/// Bars bounce at different heights to simulate audio waveform.
class _RecordingWaveform extends StatefulWidget {
  final bool isDark;
  const _RecordingWaveform({required this.isDark});

  @override
  State<_RecordingWaveform> createState() => _RecordingWaveformState();
}

class _RecordingWaveformState extends State<_RecordingWaveform>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(5, (i) {
      final c = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 400 + i * 100),
      );
      Future.delayed(Duration(milliseconds: i * 80), () {
        if (mounted) c.repeat(reverse: true);
      });
      return c;
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.error(widget.isDark);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return AnimatedBuilder(
          animation: _controllers[i],
          builder: (context, child) {
            final height = 4.0 + _controllers[i].value * 12.0;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 3,
              height: height,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.6 + _controllers[i].value * 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          },
        );
      }),
    );
  }
}
