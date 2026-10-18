import 'package:flutter/material.dart';

import '../../app/sign_talk_scope.dart';
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 16, 12),
              child: Row(
                children: [
                  Text(
                    'Logs',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Spacer(),
                  if (logs.entries.isNotEmpty)
                    IconButton(
                      tooltip: 'Clear logs',
                      onPressed: () => _confirmClear(context, logs),
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
            ),
            Expanded(
              child: logs.entries.isEmpty
                  ? const _EmptyLogs()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: _contacts(logs.entries).length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final contact = _contacts(logs.entries)[index];
                        final entries = logs.entries
                            .where((entry) => entry.contactName == contact)
                            .toList();
                        return _ContactCard(
                          contactName: contact,
                          entries: entries,
                          onTap: () => onOpenConversation(contact),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  List<String> _contacts(List<ActivityLogEntry> entries) {
    return entries.map((entry) => entry.contactName).toSet().toList();
  }

  Future<void> _confirmClear(
    BuildContext context,
    ActivityLogService logs,
  ) async {
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear logs?'),
        content: const Text(
          'This removes saved chat and video-call history from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (clear == true) await logs.clear();
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SignTalkColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SignTalkColors.border),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: SignTalkColors.tintBlue,
          child: Icon(Icons.person_outline, color: SignTalkColors.primaryBlue),
        ),
        title: Text(
          contactName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '$chatCount chats · $callCount calls\n${latest.preview}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          _dateLabel(latest.createdAt),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }

  String _dateLabel(DateTime date) {
    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class _EmptyLogs extends StatelessWidget {
  const _EmptyLogs();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history,
              size: 56,
              color: SignTalkColors.secondaryText.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              'No activity yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'Your sent chats and completed video calls will appear here.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
