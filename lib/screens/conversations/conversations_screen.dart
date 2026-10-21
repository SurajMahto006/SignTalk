import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/sign_talk_scope.dart';
import '../../services/auth/auth_service.dart';
import '../../services/communication/chat_time.dart';
import '../../services/communication/conversation_store.dart';
import '../../services/isl/text_to_sign_reference.dart';
import '../../widgets/sign_plan_card.dart';
import '../../services/speech/speech_recognition_service.dart';
import '../../services/speech/text_to_speech_service.dart';
import '../../theme/sign_talk_colors.dart';

String _captionBody(BuildContext context, ChatMessage message) {
  if (SignTalkScope.preferencesOf(context).captionsEnabled) {
    return message.body;
  }
  return 'Captions are off';
}

enum ConversationInputMode { type, speak, translate }

enum ChatMessageKind { typed, recognizedSign, spoken }

class ChatMessage {
  ChatMessage({
    required this.kind,
    required this.body,
    required this.timeLabel,
    required this.createdAt,
    this.showDelivered = false,
  });

  final ChatMessageKind kind;
  final String body;
  final String timeLabel;
  final DateTime createdAt;
  final bool showDelivered;
}

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({
    super.key,
    required this.contactName,
    required this.onOpenVideoCall,
    required this.onBack,
    this.backTooltip = 'Back to Home',
  });

  final String contactName;
  final VoidCallback onOpenVideoCall;
  final VoidCallback onBack;
  final String backTooltip;

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  ConversationInputMode _mode = ConversationInputMode.type;
  bool _dictating = false;
  final List<StreamSubscription<dynamic>> _speechSubs = [];

  final List<ChatMessage> _messages = [];
  bool _speakAfterSend = true;
  bool _loadedSpeakPreference = false;
  int _savedMessageCount = -1;
  List<SignPlanStep> _signPlan = const [];
  bool _pendingRecognizedSign = false;
  SpeechRecognitionService? _speechRecognition;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _speechRecognition ??= SignTalkScope.of(context).speechRecognition;
    if (!_loadedSpeakPreference) {
      _speakAfterSend = SignTalkScope.preferencesOf(context)
          .spokenOutputEnabled;
      _loadedSpeakPreference = true;
    }
    _restoreSavedMessages();
  }

  String _accountId() {
    return SignTalkScope.authOf(context).currentUser?.userId ??
        AuthService.demoUserId;
  }

  void _restoreSavedMessages() {
    final saved = SignTalkScope.of(context).conversations.messagesFor(
      ownerId: _accountId(),
      contactName: widget.contactName,
    );
    if (saved.length == _savedMessageCount) return;
    if (_messages.isNotEmpty && saved.length <= _messages.length) {
      _savedMessageCount = saved.length;
      return;
    }
    _messages
      ..clear()
      ..addAll(saved.map(_chatFromStored));
    _savedMessageCount = saved.length;
  }

  ChatMessage _chatFromStored(StoredChatMessage message) {
    final kind = switch (message.kind) {
      'recognizedSign' => ChatMessageKind.recognizedSign,
      'spoken' => ChatMessageKind.spoken,
      _ => ChatMessageKind.typed,
    };
    return ChatMessage(
      kind: kind,
      body: message.body,
      timeLabel: _formatTime(message.createdAt),
      createdAt: message.createdAt,
      showDelivered: kind == ChatMessageKind.recognizedSign,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bindSpeechForComposer();
      _applyDraftFromScope();
    });
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
      ..add(
        speech.finalTranscriptStream.listen((text) {
          if (_mode != ConversationInputMode.speak || text.trim().isEmpty) {
            return;
          }
          setState(() {
            _inputController.text = _inputController.text.isEmpty
                ? text.trim()
                : '${_inputController.text.trim()} ${text.trim()}';
            _dictating = false;
          });
        }),
      )
      ..add(
        speech.errorStream.listen((e) {
          if (_mode == ConversationInputMode.speak) {
            _showSnack(e);
            setState(() => _dictating = false);
          }
        }),
      )
      ..add(
        speech.listeningStream.listen((listening) {
          if (_mode == ConversationInputMode.speak &&
              !listening &&
              _dictating) {
            setState(() => _dictating = false);
          }
        }),
      );
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
      _showSnack(
        'Type text to see text-to-sign glossary hints, or send recognized sign text.',
      );
      return;
    }

    if (_mode == ConversationInputMode.speak && text.isEmpty) {
      await _startDictation(scope);
      return;
    }

    if (text.isEmpty) {
      _showSnack('Please type a message first or switch to Speak mode.');
      return;
    }

    final kind = _pendingRecognizedSign
        ? ChatMessageKind.recognizedSign
        : switch (_mode) {
            ConversationInputMode.speak => ChatMessageKind.spoken,
            _ => ChatMessageKind.typed,
          };
    _pendingRecognizedSign = false;
    final sentAt = DateTime.now();

    setState(() {
      _messages.add(
        ChatMessage(
          kind: kind,
          body: text,
          timeLabel: _formatTime(sentAt),
          createdAt: sentAt,
          showDelivered: kind == ChatMessageKind.recognizedSign,
        ),
      );
      _inputController.clear();
      _signPlan = const [];
    });
    await scope.conversations.append(
      ownerId: scope.authService.currentUser?.userId ?? AuthService.demoUserId,
      contactName: widget.contactName,
      kind: kind.name,
      body: text,
      createdAt: sentAt,
    );
    _savedMessageCount = scope.conversations
        .messagesFor(
          ownerId:
              scope.authService.currentUser?.userId ?? AuthService.demoUserId,
          contactName: widget.contactName,
        )
        .length;
    await scope.activityLogs.addChat(
      ownerId: scope.authService.currentUser?.userId ?? AuthService.demoUserId,
      contactName: widget.contactName,
      preview: text,
    );
    _scrollToBottom();
    SignTalkScope.preferencesOf(context).triggerHapticIfEnabled();

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
        detail: granted
            ? 'Used in Conversations (Speak mode)'
            : 'Denied in browser',
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

  Future<void> _messageActions(ChatMessage message) async {
    final index = _messages.indexOf(message);
    if (index < 0) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy message'),
              onTap: () => Navigator.pop(context, 'copy'),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: SignTalkColors.callRed,
              ),
              title: const Text('Delete message'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: message.body));
      _showSnack('Message copied.');
      return;
    }
    final ownerId =
        SignTalkScope.authOf(context).currentUser?.userId ??
        AuthService.demoUserId;
    setState(() => _messages.removeAt(index));
    _savedMessageCount = _messages.length;
    await SignTalkScope.of(context).conversations.removeMessage(
      ownerId: ownerId,
      contactName: widget.contactName,
      index: index,
    );
  }

  List<Object> _chatRows() {
    final rows = <Object>[];
    DateTime? previousDay;
    for (final message in _messages) {
      final day = DateTime(
        message.createdAt.year,
        message.createdAt.month,
        message.createdAt.day,
      );
      if (previousDay != day) {
        rows.add(message.createdAt);
        previousDay = day;
      }
      rows.add(message);
    }
    return rows;
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: SignTalkColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.waving_hand_outlined,
                  color: SignTalkColors.primaryBlue,
                ),
                title: const Text('Insert quick greeting'),
                subtitle: const Text(
                  'Add "Hello! I am using SignTalk." to composer',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _inputController.text =
                        'Hello! I am using SignTalk to communicate.';
                  });
                  _showSnack('Greeting inserted into composer.');
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: SignTalkColors.callRed,
                ),
                title: const Text('Clear conversation messages'),
                onTap: () {
                  Navigator.pop(ctx);
                  if (_messages.isEmpty) {
                    _showSnack('No messages to clear.');
                    return;
                  }
                  setState(() {
                    _messages.clear();
                    _signPlan = const [];
                  });
                  _savedMessageCount = 0;
                  unawaited(
                    SignTalkScope.of(context).conversations.clearContact(
                      ownerId: _accountId(),
                      contactName: widget.contactName,
                    ),
                  );
                  _showSnack('Conversation cleared.');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ConversationsHeader(
          contactName: widget.contactName,
          onBack: widget.onBack,
          backTooltip: widget.backTooltip,
          onVideoCall: widget.onOpenVideoCall,
          onMore: _showMoreOptions,
        ),
        Expanded(
          child: _messages.isEmpty
              ? const _EmptyConversation()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: _chatRows().length,
                  itemBuilder: (context, index) {
                    final row = _chatRows()[index];
                    if (row is DateTime) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: _DatePill(
                            label: chatDayLabel(row, DateTime.now()),
                          ),
                        ),
                      );
                    }
                    final message = row as ChatMessage;
                    return GestureDetector(
                      onLongPress: () => unawaited(_messageActions(message)),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MessageBubble(
                          message: message,
                          onSpeak: () => unawaited(_speakMessage(message.body)),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (_mode == ConversationInputMode.translate && _signPlan.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SignPlanCard(steps: _signPlan),
          ),
        _ComposerSection(
          mode: _mode,
          dictating: _dictating,
          speakAfterSend: _speakAfterSend,
          controller: _inputController,
          onSpeakAfterSendChanged: (v) {
            setState(() => _speakAfterSend = v);
            unawaited(
              SignTalkScope.preferencesOf(context).setSpokenOutputEnabled(v),
            );
          },
          onTextChanged: (v) => setState(() {
            _signPlan = _mode == ConversationInputMode.translate
                ? TextToSignReference.planForText(v)
                : const [];
          }),
          onQuickReply: (phrase) {
            final current = _inputController.text.trim();
            final next = current.isEmpty ? phrase : '$current $phrase';
            setState(() {
              _inputController.text = next;
              _inputController.selection = TextSelection.collapsed(
                offset: next.length,
              );
              if (_mode == ConversationInputMode.translate) {
                _signPlan = TextToSignReference.planForText(next);
              }
            });
          },
          onModeChanged: (mode) {
            setState(() {
              _mode = mode;
              _signPlan = mode == ConversationInputMode.translate
                  ? TextToSignReference.planForText(_inputController.text)
                  : const [];
            });
            if (mode != ConversationInputMode.speak) {
              unawaited(
                SignTalkScope.of(context).speechRecognition.stopListening(),
              );
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
  const _ConversationsHeader({
    required this.contactName,
    required this.onBack,
    required this.backTooltip,
    required this.onVideoCall,
    required this.onMore,
  });

  final String contactName;
  final VoidCallback onBack;
  final String backTooltip;
  final VoidCallback onVideoCall;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 12),
      child: Row(
        children: [
          _HeaderIconButton(
            icon: Icons.arrow_back_ios_new,
            tooltip: backTooltip,
            onPressed: onBack,
          ),
          const SizedBox(width: 12),
          _ContactAvatar(name: contactName),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contactName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: SignTalkColors.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                const Row(
                  children: [
                    _OfflineDot(),
                    SizedBox(width: 5),
                    Text(
                      'Offline',
                      style: TextStyle(
                        fontSize: 12,
                        color: SignTalkColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _HeaderIconButton(
            icon: Icons.videocam_rounded,
            tooltip: 'Start video call',
            onPressed: onVideoCall,
          ),
          const SizedBox(width: 8),
          _HeaderIconButton(
            icon: Icons.more_vert_rounded,
            tooltip: 'Conversation options',
            onPressed: onMore,
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SignTalkColors.blueTint,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Tooltip(
            message: tooltip,
            child: Icon(icon, color: SignTalkColors.primaryBlue, size: 21),
          ),
        ),
      ),
    );
  }
}

class _ContactAvatar extends StatelessWidget {
  const _ContactAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();
    return CircleAvatar(
      radius: 29,
      backgroundColor: SignTalkColors.primaryBlue,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _OfflineDot extends StatelessWidget {
  const _OfflineDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: SignTalkColors.secondaryText,
        shape: BoxShape.circle,
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
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: SignTalkColors.secondaryText,
          ),
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
      ChatMessageKind.spoken => _SpokenBubble(
        message: message,
        onSpeak: onSpeak,
      ),
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
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: SignTalkColors.secondaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _captionBody(context, message),
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.45,
              color: SignTalkColors.primaryText,
            ),
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
                tooltip: 'Speak message',
              ),
              Text(
                message.timeLabel,
                style: const TextStyle(
                  fontSize: 11,
                  color: SignTalkColors.secondaryText,
                ),
              ),
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
                decoration: const BoxDecoration(
                  color: SignTalkColors.primaryBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.back_hand_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 14,
                          color: SignTalkColors.primaryBlue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Recognized Sign',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: SignTalkColors.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _captionBody(context, message),
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.35,
                        color: SignTalkColors.primaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                message.timeLabel,
                style: const TextStyle(
                  fontSize: 11,
                  color: SignTalkColors.secondaryText,
                ),
              ),
              if (message.showDelivered) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.done_all,
                  size: 16,
                  color: SignTalkColors.primaryBlue,
                ),
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
                decoration: const BoxDecoration(
                  color: SignTalkColors.tintBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mic_none_outlined,
                  color: SignTalkColors.primaryBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.mic_none_outlined,
                          size: 14,
                          color: SignTalkColors.primaryBlue,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Spoken Text',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: SignTalkColors.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _captionBody(context, message),
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.35,
                        color: SignTalkColors.primaryText,
                      ),
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
              Text(
                message.timeLabel,
                style: const TextStyle(
                  fontSize: 11,
                  color: SignTalkColors.secondaryText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BubbleCard extends StatelessWidget {
  const _BubbleCard({
    required this.child,
    required this.background,
    required this.borderColor,
  });

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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: child,
      ),
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
    required this.onQuickReply,
    required this.onModeChanged,
    required this.onSend,
  });

  final ConversationInputMode mode;
  final bool dictating;
  final bool speakAfterSend;
  final TextEditingController controller;
  final ValueChanged<bool> onSpeakAfterSendChanged;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<String> onQuickReply;
  final ValueChanged<ConversationInputMode> onModeChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: SignTalkColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: SignTalkColors.border),
        boxShadow: const [SignTalkColors.cardShadow],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ModePill(
                  label: 'Type',
                  icon: Icons.keyboard_outlined,
                  selected: mode == ConversationInputMode.type,
                  onTap: () => onModeChanged(ConversationInputMode.type),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ModePill(
                  label: 'Speak',
                  icon: Icons.mic_none_outlined,
                  selected: mode == ConversationInputMode.speak,
                  onTap: () => onModeChanged(ConversationInputMode.speak),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ModePill(
                  label: 'Translate',
                  icon: Icons.tune,
                  selected: mode == ConversationInputMode.translate,
                  onTap: () => onModeChanged(ConversationInputMode.translate),
                ),
              ),
            ],
          ),
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeThumbColor: SignTalkColors.primaryBlue,
              secondary: const Icon(
                Icons.volume_up_rounded,
                color: SignTalkColors.primaryBlue,
              ),
              title: const Text(
                'Speak aloud after send',
                style: TextStyle(fontSize: 13),
              ),
              value: speakAfterSend,
              onChanged: onSpeakAfterSendChanged,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final phrase in const [
                  'Hello',
                  'Thank you',
                  'Please',
                  'Help',
                  'Yes',
                  'No',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(phrase),
                      onPressed: () => onQuickReply(phrase),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
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
                        dictating
                            ? 'Listening…'
                            : 'Tap send to dictate, then send again',
                      ConversationInputMode.translate =>
                        'Text-to-sign glossary (type hello, thankyou…)',
                      _ => 'Type a message...',
                    },
                    prefixIcon: const Icon(
                      Icons.sentiment_satisfied_alt_outlined,
                      color: SignTalkColors.secondaryText,
                    ),
                    filled: true,
                    fillColor: SignTalkColors.card,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: const BorderSide(
                        color: SignTalkColors.border,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: const BorderSide(
                        color: SignTalkColors.border,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: const BorderSide(
                        color: SignTalkColors.primaryBlue,
                      ),
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
                    child: Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
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
      color: selected ? SignTalkColors.primaryBlue : SignTalkColors.card,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? SignTalkColors.primaryBlue
                  : SignTalkColors.border.withValues(alpha: 0.8),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: selected ? Colors.white : SignTalkColors.primaryBlue,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected
                          ? Colors.white
                          : SignTalkColors.primaryText,
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
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _ConversationIllustration(),
              const SizedBox(height: 10),
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: SignTalkColors.primaryText,
                  ),
                  children: [
                    TextSpan(text: 'Start the '),
                    TextSpan(
                      text: 'Conversation',
                      style: TextStyle(color: SignTalkColors.primaryBlue),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'No messages yet. Use Speech to Text or type here.\n'
                'Enable “Speak aloud after send” for the demo flow.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: SignTalkColors.secondaryText,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationIllustration extends StatelessWidget {
  const _ConversationIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 205,
      width: 300,
      child: CustomPaint(
        painter: _ConversationIllustrationPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ConversationIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final blue = Paint()..color = SignTalkColors.primaryBlue;
    final dark = Paint()..color = const Color(0xFF3A2530);
    final skin = Paint()..color = const Color(0xFFFFC49F);
    final cream = Paint()..color = const Color(0xFFFFE6D3);
    final hair = Paint()..color = const Color(0xFF2C1D2B);
    final white = Paint()..color = Colors.white;

    canvas.drawOval(
      Rect.fromLTWH(25, 40, size.width - 50, size.height - 32),
      Paint()..color = const Color(0xFFF0F6FF),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(102, 4, 96, 50),
        const Radius.circular(14),
      ),
      Paint()..color = const Color(0xFFE7F0FF),
    );
    _drawHand(canvas, const Offset(132, 18), blue);
    _drawHand(canvas, const Offset(165, 18), blue);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(164, 72, 92, 50),
        const Radius.circular(14),
      ),
      white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(174, 83, 24, 28),
        const Radius.circular(5),
      ),
      blue,
    );
    final letterPainter = TextPainter(
      text: const TextSpan(
        text: 'A',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    letterPainter.paint(canvas, const Offset(181, 87));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(205, 86, 38, 5),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFB8C2D4),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(205, 98, 29, 5),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFB8C2D4),
    );

    canvas.drawOval(Rect.fromLTWH(58, 73, 65, 66), skin);
    canvas.drawOval(Rect.fromLTWH(53, 67, 75, 38), dark);
    canvas.drawPath(
      Path()
        ..moveTo(48, 124)
        ..quadraticBezierTo(85, 103, 130, 127)
        ..lineTo(143, 199)
        ..lineTo(39, 199)
        ..close(),
      blue,
    );
    canvas.drawOval(Rect.fromLTWH(76, 91, 8, 11), dark);
    canvas.drawOval(Rect.fromLTWH(101, 91, 8, 11), dark);
    canvas.drawArc(
      Rect.fromLTWH(78, 98, 29, 22),
      0,
      3.14,
      false,
      Paint()
        ..color = dark.color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    canvas.drawLine(
      const Offset(92, 139),
      const Offset(127, 113),
      skin
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      const Offset(129, 111),
      const Offset(131, 83),
      skin
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(131, 79), 6, skin);
    canvas.drawLine(
      const Offset(131, 80),
      const Offset(137, 68),
      skin
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawOval(Rect.fromLTWH(215, 106, 55, 61), skin);
    canvas.drawOval(Rect.fromLTWH(209, 99, 67, 42), hair);
    canvas.drawPath(
      Path()
        ..moveTo(209, 151)
        ..quadraticBezierTo(242, 130, 277, 157)
        ..lineTo(286, 199)
        ..lineTo(199, 199)
        ..close(),
      cream,
    );
    canvas.drawOval(Rect.fromLTWH(226, 127, 7, 10), dark);
    canvas.drawOval(Rect.fromLTWH(249, 127, 7, 10), dark);
    canvas.drawArc(
      Rect.fromLTWH(227, 134, 25, 18),
      0,
      3.14,
      false,
      Paint()
        ..color = dark.color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawHand(Canvas canvas, Offset origin, Paint paint) {
    canvas.drawCircle(origin + const Offset(0, 17), 10, paint);
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(
        origin + Offset(i * 7 - 10, 15),
        origin + Offset(i * 7 - 10, i == 1 ? -1 : 5),
        paint
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
