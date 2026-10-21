import 'package:flutter/material.dart';

import '../../app/sign_talk_scope.dart';
import '../../services/auth/auth_service.dart';
import '../../services/logs/activity_log_service.dart';
import '../../theme/sign_talk_colors.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key, required this.onOpenConversation});

  final ValueChanged<String> onOpenConversation;

  @override
  Widget build(BuildContext context) {
    final logs = SignTalkScope.of(context).activityLogs;
    return ListenableBuilder(
      listenable: logs,
      builder: (context, _) {
        final ownerId =
            SignTalkScope.authOf(context).currentUser?.userId ??
            AuthService.demoUserId;
        final mine = logs.entriesFor(ownerId);
        final contacts = _groupContacts(mine);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Logs',
                          style: TextStyle(
                            fontSize: 24,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: SignTalkColors.primaryText,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your conversations and calls in one place.',
                          style: TextStyle(
                            fontSize: 14,
                            color: SignTalkColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _DeleteButton(
                    enabled: mine.isNotEmpty,
                    onPressed: () => _confirmClear(context, logs, ownerId),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: contacts.isEmpty
                  ? const _EmptyLogs()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      children: [
                        const Text(
                          'Recent activity',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: SignTalkColors.primaryText,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ...contacts.map(
                          (contact) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ContactCard(
                              contactName: contact.name,
                              entries: contact.entries,
                              onTap: () => onOpenConversation(contact.name),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  List<_ContactActivity> _groupContacts(List<ActivityLogEntry> entries) {
    final grouped = <String, List<ActivityLogEntry>>{};
    for (final entry in entries) {
      grouped.putIfAbsent(entry.contactName, () => []).add(entry);
    }
    final contacts = grouped.entries
        .map((entry) => _ContactActivity(entry.key, entry.value))
        .toList();
    contacts.sort(
      (a, b) => b.entries.first.createdAt.compareTo(a.entries.first.createdAt),
    );
    return contacts;
  }

  Future<void> _confirmClear(
    BuildContext context,
    ActivityLogService logs,
    String ownerId,
  ) async {
    if (logs.entriesFor(ownerId).isEmpty) return;
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete activity history?'),
        content: const Text(
          'This removes your chat and call history on this phone. Other accounts keep theirs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: SignTalkColors.callRed,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (clear != true || !context.mounted) return;
    try {
      await logs.clearOwner(ownerId);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete activity history.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _ContactActivity {
  _ContactActivity(this.name, this.entries);

  final String name;
  final List<ActivityLogEntry> entries;
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled
          ? SignTalkColors.card
          : SignTalkColors.card.withValues(alpha: 0.6),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Tooltip(
            message: enabled
                ? 'Delete activity history'
                : 'No activity to delete',
            child: Icon(
              Icons.delete_outline_rounded,
              color: enabled
                  ? SignTalkColors.secondaryText
                  : SignTalkColors.secondaryText.withValues(alpha: 0.45),
              size: 25,
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.contactName,
    required this.entries,
    required this.onTap,
  });

  final String contactName;
  final List<ActivityLogEntry> entries;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final latest = entries.first;
    final callCount = entries
        .where((entry) => entry.type == ActivityLogType.call)
        .length;
    final chatCount = entries
        .where((entry) => entry.type == ActivityLogType.chat)
        .length;
    return Material(
      color: SignTalkColors.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: SignTalkColors.border),
            boxShadow: const [SignTalkColors.cardShadow],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 14, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ContactAvatar(name: contactName),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              contactName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: SignTalkColors.primaryText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _timeLabel(latest.createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: SignTalkColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _CountBadge(
                            icon: Icons.chat_bubble_rounded,
                            count: chatCount,
                            label: 'chats',
                          ),
                          _CountBadge(
                            icon: Icons.call_rounded,
                            count: callCount,
                            label: 'calls',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.people_alt_outlined,
                            size: 19,
                            color: SignTalkColors.secondaryText,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _roomLabel(entries),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: SignTalkColors.secondaryText,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 24,
                            color: SignTalkColors.secondaryText,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _roomLabel(List<ActivityLogEntry> entries) {
    for (final entry in entries) {
      if (entry.type == ActivityLogType.call &&
          entry.preview.toLowerCase().startsWith('room:')) {
        return entry.preview;
      }
    }
    return 'Conversation activity';
  }

  String _timeLabel(DateTime date) {
    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'}';
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
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return Container(
      width: 68,
      height: 68,
      decoration: const BoxDecoration(
        color: SignTalkColors.primaryBlue,
        shape: BoxShape.circle,
        boxShadow: [SignTalkColors.cardShadow],
      ),
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.icon,
    required this.count,
    required this.label,
  });

  final IconData icon;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SignTalkColors.tintBlue,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: SignTalkColors.primaryBlue),
            const SizedBox(width: 6),
            Text(
              '$count $label',
              style: const TextStyle(
                fontSize: 12,
                color: SignTalkColors.secondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLogs extends StatelessWidget {
  const _EmptyLogs();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 300,
              height: 260,
              child: CustomPaint(painter: _LogsEmptyPainter()),
            ),
            const SizedBox(height: 14),
            const Text(
              'Your activity will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: SignTalkColors.primaryText,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'All your chats, calls and room activity will be shown\n'
              'here for easy access.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: SignTalkColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogsEmptyPainter extends CustomPainter {
  const _LogsEmptyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final blue = Paint()..color = SignTalkColors.primaryBlue;
    final paleBlue = Paint()..color = const Color(0xFFEAF3FF);
    final line = Paint()
      ..color = const Color(0xFFB8C8E4)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(const Offset(107, 106), 52, paleBlue);
    canvas.drawCircle(
      const Offset(196, 114),
      56,
      Paint()..color = const Color(0xFFF0F6FF),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(68, 54, 148, 152),
        const Radius.circular(20),
      ),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(68, 54, 148, 152),
        const Radius.circular(20),
      ),
      Paint()
        ..color = const Color(0xFFDCE9FC)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _drawRow(
      canvas,
      const Offset(89, 86),
      Icons.chat_bubble_rounded,
      blue,
      line,
    );
    _drawRow(canvas, const Offset(89, 125), Icons.call_rounded, blue, line);
    _drawRow(
      canvas,
      const Offset(89, 164),
      Icons.people_alt_rounded,
      blue,
      line,
    );

    canvas.drawCircle(const Offset(206, 166), 40, paleBlue);
    canvas.drawCircle(
      const Offset(206, 166),
      39,
      Paint()
        ..color = blue.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11,
    );
    canvas.drawLine(
      const Offset(235, 195),
      const Offset(267, 226),
      blue
        ..strokeWidth = 15
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      const Offset(23, 106),
      7,
      Paint()..color = const Color(0xFF7CB7FF),
    );
  }

  void _drawRow(
    Canvas canvas,
    Offset offset,
    IconData icon,
    Paint blue,
    Paint line,
  ) {
    canvas.drawCircle(offset, 14, Paint()..color = const Color(0xFFEAF3FF));
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: 15,
          color: blue.color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      offset - Offset(painter.width / 2, painter.height / 2),
    );
    canvas.drawLine(
      offset + const Offset(27, -4),
      offset + const Offset(80, -4),
      line,
    );
    canvas.drawLine(
      offset + const Offset(27, 7),
      offset + const Offset(65, 7),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
