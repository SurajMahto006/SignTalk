import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/sign_talk_scope.dart';
import '../../services/isl/text_to_sign_reference.dart';
import '../../services/speech/speech_recognition_service.dart';
import '../../services/speech/text_to_speech_service.dart';
import '../../theme/sign_talk_colors.dart';

enum ConversationInputMode { type, speak, translate }

enum ChatMessageKind { typed, recognizedSign, spoken }

class ChatMessage {
  ChatMessage({
    required this.kind,
    required this.body,
    required this.timeLabel,
    this.showDelivered = false,
  });

  final ChatMessageKind kind;
  final String body;
  final String timeLabel;
  final bool showDelivered;

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'body': body,
        'timeLabel': timeLabel,
        'showDelivered': showDelivered,
      };

  /// Returns `null` if [json] is missing required fields or has an unknown kind.
  static ChatMessage? fromJson(Map<String, dynamic> json) {
    try {
      final kindName = json['kind'] as String?;
      final body = json['body'] as String?;
      final timeLabel = json['timeLabel'] as String?;
      if (kindName == null || body == null || timeLabel == null) return null;
      final kind = ChatMessageKind.values.firstWhere(
        (k) => k.name == kindName,
        orElse: () => throw FormatException('Unknown kind: $kindName'),
      );
      return ChatMessage(
        kind: kind,
        body: body,
        timeLabel: timeLabel,
        showDelivered: json['showDelivered'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }
}

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key, required this.onOpenVideoCall});

  final VoidCallback onOpenVideoCall;

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  static const _kMessagesKey = 'st_chat_messages_v1';

  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  ConversationInputMode _mode = ConversationInputMode.type;
  bool _dictating = false;
  final List<StreamSubscription<dynamic>> _speechSubs = [];

  final List<ChatMessage> _messages = [];
  bool _speakAfterSend = true;
  String? _translateHint;
  bool _pendingRecognizedSign = false;
  SpeechRecognitionService? _speechRecognition;

  /// Completes once the saved history has been loaded from SharedPreferences.
  /// Every save waits for this so an early send never overwrites stored history.
  late final Future<void> _historyLoaded;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _speechRecognition ??= SignTalkScope.of(context).speechRecognition;
  }

  @override
  void initState() {
    super.initState();
    _historyLoaded = _loadMessages();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bindSpeechForComposer();
      _applyDraftFromScope();
    });
  }

  // ---------------------------------------------------------------------------
  // Persistence helpers
  // ---------------------------------------------------------------------------

  /// Reads messages from SharedPreferences and populates [_messages].
  /// Silently ignores any corrupt or missing data.
  Future<void> _loadMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kMessagesKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final loaded = <ChatMessage>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final msg = ChatMessage.fromJson(item);
          if (msg != null) loaded.add(msg);
        }
      }
      if (loaded.isNotEmpty && mounted) {
        setState(() => _messages.addAll(loaded));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SignTalk: failed to load messages – $e');
    }
  }

  /// Serialises [_messages] to JSON and writes to SharedPreferences.
  /// Waits for [_historyLoaded] first, so a rapid first send cannot race
  /// against the initial read and overwrite saved history.
  Future<void> _saveMessages() async {
    try {
      await _historyLoaded;
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_messages.map((m) => m.toJson()).toList());
      await prefs.setString(_kMessagesKey, encoded);
    } catch (e) {
      if (kDebugMode) debugPrint('SignTalk: failed to save messages – $e');
    }
  }

  /// Clears all messages from memory and from SharedPreferences.
  Future<void> _clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kMessagesKey);
    } catch (e) {
      if (kDebugMode) debugPrint('SignTalk: failed to clear messages – $e');
    }
    if (mounted) setState(() => _messages.clear());
  }

  void _applyDraftFromScope() {
    final draft = SignTalkScope.of(context).conversationDraft.consume();
    if (draft == null) return;
    _inputController.text = draft.text;
    _pendingRecognizedSign = draft.asRecognizedSign;
    if (draft.asSpoken) {
      _mode = ConversationInputMode.speak;
    } else {
      _mode = ConversationInputMode.type;
    }
    setState(() {});
  }

  void _bindSpeechForComposer() {
    final speech = SignTalkScope.of(context).speechRecognition;
    _speechSubs
      ..add(speech.finalTranscriptStream.listen((text) {
        if (_mode != ConversationInputMode.speak || text.trim().isEmpty) return;
        setState(() {
          _inputController.text = _inputController.text.isEmpty
              ? text.trim()
              : '${_inputController.text.trim()} ${text.trim()}';
          _dictating = false;
        });
      }))
      ..add(speech.errorStream.listen((e) {
        if (_mode == ConversationInputMode.speak) {
          _showSnack(e);
          setState(() => _dictating = false);
        }
      }))
      ..add(speech.listeningStream.listen((listening) {
        if (_mode == ConversationInputMode.speak && !listening && _dictating) {
          setState(() => _dictating = false);
        }
      }));
  }

  @override
  void dispose() {
    for (final sub in _speechSubs) {
      unawaited(sub.cancel());
    }
    final speech = _speechRecognition;
    if (speech != null) {
      unawaited(speech.stopListening());
    }
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final scope = SignTalkScope.of(context);
    final text = _inputController.text.trim();

    if (_mode == ConversationInputMode.translate && text.isEmpty) {
      _showSnack('Type text to see text-to-sign glossary hints, or send recognized sign text.');
      return;
    }

    if (_mode == ConversationInputMode.speak && text.isEmpty) {
      await _startDictation(scope);
      return;
    }

    if (text.isEmpty) return;

    final kind = _pendingRecognizedSign
        ? ChatMessageKind.recognizedSign
        : switch (_mode) {
            ConversationInputMode.speak => ChatMessageKind.spoken,
            _ => ChatMessageKind.typed,
          };
    _pendingRecognizedSign = false;

    setState(() {
      _messages.add(
        ChatMessage(
          kind: kind,
          body: text,
          timeLabel: _formatTime(DateTime.now()),
          showDelivered: kind == ChatMessageKind.recognizedSign,
        ),
      );
      _inputController.clear();
      _translateHint = null;
    });
    _scrollToBottom();
    unawaited(_saveMessages());

    if (_speakAfterSend) {
      await _speakMessage(text);
    }
  }

  Future<void> _startDictation(SignTalkScope scope) async {
    final speech = scope.speechRecognition;
    final ok = await speech.initialize();
    if (!ok) {
      _showSnack('Speech recognition is unavailable in this browser.');
      return;
    }
    setState(() => _dictating = true);
    await speech.startListening();
    final granted = speech.lastPermissionGranted;
    if (granted != null) {
      scope.permissionStatus.reportMicrophone(
        granted: granted,
        detail: granted ? 'Used in Conversations (Speak mode)' : 'Denied in browser',
      );
    }
    _showSnack('Listening… speak, then tap send again to post as Spoken Text.');
  }

  Future<void> _speakMessage(String body) async {
    final prefs = SignTalkScope.preferencesOf(context);
    final tts = SignTalkScope.of(context).textToSpeech;
    if (!prefs.spokenOutputEnabled) {
      _showSnack('Spoken output is off in Settings.');
      return;
    }
    await tts.setLanguage(prefs.speechLocale);
    final outcome = await tts.speak(body, enabled: prefs.spokenOutputEnabled);
    if (outcome == SpeakOutcome.failed || outcome == SpeakOutcome.unavailable) {
      _showSnack('Could not speak this message.');
    }
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ConversationsHeader(
          onVideoCall: widget.onOpenVideoCall,
          onMore: () async {
            if (_messages.isEmpty) {
              _showSnack('No messages to clear.');
              return;
            }
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Clear history?'),
                content: const Text('This will permanently delete all messages in this conversation.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Clear', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
            if (confirmed == true) unawaited(_clearHistory());
          },
        ),
        Expanded(
          child: _messages.isEmpty
              ? const _EmptyConversation()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: _messages.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(child: _DatePill(label: 'Today, 14 Oct')),
                      );
                    }
                    final message = _messages[index - 1];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MessageBubble(message: message, onSpeak: () => unawaited(_speakMessage(message.body))),
                    );
                  },
                ),
        ),
        if (_mode == ConversationInputMode.translate && _translateHint != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(_translateHint!, style: Theme.of(context).textTheme.bodySmall),
          ),
        _ComposerSection(
          mode: _mode,
          dictating: _dictating,
          speakAfterSend: _speakAfterSend,
          controller: _inputController,
          onSpeakAfterSendChanged: (v) => setState(() => _speakAfterSend = v),
          onTextChanged: (v) => setState(() {
            _translateHint = _mode == ConversationInputMode.translate
                ? TextToSignReference.hintForText(v)
                : null;
          }),
          onModeChanged: (mode) {
            setState(() {
              _mode = mode;
              _translateHint = mode == ConversationInputMode.translate
                  ? TextToSignReference.hintForText(_inputController.text)
                  : null;
            });
            if (mode != ConversationInputMode.speak) {
              unawaited(SignTalkScope.of(context).speechRecognition.stopListening());
              setState(() => _dictating = false);
            }
          },
          onSend: () => unawaited(_sendMessage()),
        ),
      ],
    );
  }
}

class _ConversationsHeader extends StatelessWidget {
  const _ConversationsHeader({required this.onVideoCall, required this.onMore});

  final VoidCallback onVideoCall;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: SignTalkColors.primaryText,
          ),
          const Expanded(
            child: Text(
              'Conversations',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: SignTalkColors.primaryText),
            ),
          ),
          IconButton(
            onPressed: onVideoCall,
            icon: const Icon(Icons.videocam_outlined, size: 22),
            color: SignTalkColors.primaryBlue,
            tooltip: 'Video call prototype',
          ),
          IconButton(
            onPressed: onMore,
            icon: const Icon(Icons.more_horiz, size: 22),
            color: SignTalkColors.primaryText,
          ),
        ],
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SignTalkColors.card.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: SignTalkColors.border.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: SignTalkColors.secondaryText),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.onSpeak});

  final ChatMessage message;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    return switch (message.kind) {
      ChatMessageKind.typed => _TypedBubble(message: message, onSpeak: onSpeak),
      ChatMessageKind.recognizedSign => _SignBubble(message: message),
      ChatMessageKind.spoken => _SpokenBubble(message: message, onSpeak: onSpeak),
    };
  }
}

class _TypedBubble extends StatelessWidget {
  const _TypedBubble({required this.message, required this.onSpeak});

  final ChatMessage message;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    return _BubbleCard(
      background: SignTalkColors.card,
      borderColor: SignTalkColors.border.withValues(alpha: 0.6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'You (Typed Text)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: SignTalkColors.secondaryText),
          ),
          const SizedBox(height: 6),
          Text(message.body, style: const TextStyle(fontSize: 14.5, height: 1.45, color: SignTalkColors.primaryText)),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: onSpeak,
                icon: const Icon(Icons.volume_up_outlined, size: 18),
                color: SignTalkColors.primaryBlue,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Speak message',
              ),
              Text(message.timeLabel, style: const TextStyle(fontSize: 11, color: SignTalkColors.secondaryText)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignBubble extends StatelessWidget {
  const _SignBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return _BubbleCard(
      background: SignTalkColors.tintBlue,
      borderColor: SignTalkColors.tintBlueBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: SignTalkColors.primaryBlue, shape: BoxShape.circle),
                child: const Icon(Icons.back_hand_outlined, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 14, color: SignTalkColors.primaryBlue),
                        const SizedBox(width: 4),
                        Text(
                          'Recognized Sign',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SignTalkColors.primaryBlue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message.body,
                      style: const TextStyle(fontSize: 14.5, height: 1.35, color: SignTalkColors.primaryText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(message.timeLabel, style: const TextStyle(fontSize: 11, color: SignTalkColors.secondaryText)),
              if (message.showDelivered) ...[
                const SizedBox(width: 4),
                const Icon(Icons.done_all, size: 16, color: SignTalkColors.primaryBlue),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SpokenBubble extends StatelessWidget {
  const _SpokenBubble({required this.message, required this.onSpeak});

  final ChatMessage message;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    return _BubbleCard(
      background: SignTalkColors.card,
      borderColor: SignTalkColors.border.withValues(alpha: 0.6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: SignTalkColors.tintBlue, shape: BoxShape.circle),
                child: const Icon(Icons.mic_none_outlined, color: SignTalkColors.primaryBlue, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.mic_none_outlined, size: 14, color: SignTalkColors.primaryBlue),
                        SizedBox(width: 4),
                        Text(
                          'Spoken Text',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SignTalkColors.primaryBlue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message.body,
                      style: const TextStyle(fontSize: 14.5, height: 1.35, color: SignTalkColors.primaryText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: onSpeak,
                icon: const Icon(Icons.volume_up_outlined, size: 18),
                color: SignTalkColors.primaryBlue,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Speak again',
              ),
              Text(message.timeLabel, style: const TextStyle(fontSize: 11, color: SignTalkColors.secondaryText)),
            ],
          ),
        ],
      ),
    );
  }
}

class _BubbleCard extends StatelessWidget {
  const _BubbleCard({required this.child, required this.background, required this.borderColor});

  final Widget child;
  final Color background;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 12), child: child),
    );
  }
}

class _ComposerSection extends StatelessWidget {
  const _ComposerSection({
    required this.mode,
    required this.dictating,
    required this.speakAfterSend,
    required this.controller,
    required this.onSpeakAfterSendChanged,
    required this.onTextChanged,
    required this.onModeChanged,
    required this.onSend,
  });

  final ConversationInputMode mode;
  final bool dictating;
  final bool speakAfterSend;
  final TextEditingController controller;
  final ValueChanged<bool> onSpeakAfterSendChanged;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<ConversationInputMode> onModeChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _ModePill(label: 'Type', icon: Icons.keyboard_outlined, selected: mode == ConversationInputMode.type, onTap: () => onModeChanged(ConversationInputMode.type))),
              const SizedBox(width: 10),
              Expanded(child: _ModePill(label: 'Speak', icon: Icons.mic_none_outlined, selected: mode == ConversationInputMode.speak, onTap: () => onModeChanged(ConversationInputMode.speak))),
              const SizedBox(width: 10),
              Expanded(child: _ModePill(label: 'Translate', icon: Icons.tune, selected: mode == ConversationInputMode.translate, onTap: () => onModeChanged(ConversationInputMode.translate))),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Speak aloud after send', style: TextStyle(fontSize: 13)),
            value: speakAfterSend,
            onChanged: onSpeakAfterSendChanged,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onTextChanged,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: switch (mode) {
                      ConversationInputMode.speak =>
                        dictating ? 'Listening…' : 'Tap send to dictate, then send again',
                      ConversationInputMode.translate =>
                        'Text-to-sign glossary (type hello, thankyou…)',
                      _ => 'Type a message...',
                    },
                    filled: true,
                    fillColor: SignTalkColors.card,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: const BorderSide(color: SignTalkColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: const BorderSide(color: SignTalkColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: const BorderSide(color: SignTalkColors.primaryBlue),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: SignTalkColors.primaryBlue,
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  onTap: onSend,
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(Icons.chevron_right, color: Colors.white, size: 26),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? SignTalkColors.tintBlue : SignTalkColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? SignTalkColors.primaryBlue.withValues(alpha: 0.35) : SignTalkColors.border.withValues(alpha: 0.8)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: SignTalkColors.primaryBlue),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: SignTalkColors.primaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No messages yet. Use Speech to Text or type here. Enable “Speak aloud after send” for the demo flow.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
