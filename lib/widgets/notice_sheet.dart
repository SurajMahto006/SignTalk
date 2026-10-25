import 'package:flutter/material.dart';

import '../app/sign_talk_scope.dart';
import '../services/notices/notice_center.dart';
import '../theme/sign_talk_colors.dart';

Future<void> showNoticeSheet(BuildContext context) async {
  final scope = SignTalkScope.of(context);
  final notices = scope.notices.collect(
    permissions: scope.permissionStatus,
    preferences: SignTalkScope.preferencesOf(context),
    logs: scope.activityLogs.entries,
  );
  await scope.notices.markSeen();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => NoticeSheet(notices: notices),
  );
}

class NoticeSheet extends StatelessWidget {
  const NoticeSheet({super.key, required this.notices});

  final List<AppNotice> notices;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: SignTalkColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Notifications',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (notices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  'You are all caught up.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: notices.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final notice = notices[index];
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: SignTalkColors.tintBlue,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: SignTalkColors.tintBlueBorder),
                      ),
                      child: ListTile(
                        leading: Icon(
                          _iconFor(notice.kind),
                          color: SignTalkColors.primaryBlue,
                        ),
                        title: Text(
                          notice.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(notice.body),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(NoticeKind kind) {
    return switch (kind) {
      NoticeKind.cameraDenied => Icons.videocam_off_outlined,
      NoticeKind.microphoneDenied => Icons.mic_off_outlined,
      NoticeKind.captionsOff => Icons.closed_caption_off_outlined,
      NoticeKind.speechOff => Icons.volume_off_outlined,
      NoticeKind.settingsError => Icons.error_outline,
      NoticeKind.chat => Icons.chat_bubble_outline,
      NoticeKind.call => Icons.videocam_outlined,
    };
  }
}

class NoticeBellButton extends StatelessWidget {
  const NoticeBellButton({super.key, required this.showBadge});

  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: showBadge ? 'Notifications, new updates' : 'Notifications',
      child: Material(
        color: SignTalkColors.card,
        shape: const CircleBorder(
          side: BorderSide(color: SignTalkColors.border),
        ),
        child: Semantics(
          button: true,
          label: showBadge ? 'Notifications, new updates' : 'Notifications',
          child: InkWell(
            onTap: () => showNoticeSheet(context),
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.notifications_none_rounded,
                    color: SignTalkColors.primaryText,
                    size: 23,
                  ),
                  if (showBadge)
                    const Positioned(
                      right: 10,
                      top: 10,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: SignTalkColors.callRed,
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox(width: 8, height: 8),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
