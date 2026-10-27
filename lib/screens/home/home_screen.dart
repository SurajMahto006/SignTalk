import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/sign_talk_scope.dart';
import '../../theme/sign_talk_colors.dart';
import '../../widgets/notice_sheet.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onSignToTextTap,
    required this.onSpeechToTextTap,
    required this.onOpenConversations,
    this.onOpenContacts,
    this.onOpenLogs,
    this.onProfileTap,
    this.onLearnTap,
  });

  final VoidCallback onSignToTextTap;
  final VoidCallback onSpeechToTextTap;
  final VoidCallback onOpenConversations;
  final VoidCallback? onOpenContacts;
  final VoidCallback? onOpenLogs;
  final VoidCallback? onProfileTap;
  final VoidCallback? onLearnTap;

  @override
  Widget build(BuildContext context) {
    final user = SignTalkScope.authOf(context).currentUser;
    final name = user?.name.trim().split(RegExp(r'\s+')).first ?? 'Demo User';

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 560;
        return ListView(
          padding: EdgeInsets.fromLTRB(wide ? 24 : 18, 12, wide ? 24 : 18, 24),
          children: [
            _HomeHeader(
              onProfileTap: onProfileTap,
              onNotificationsTap: () => unawaited(showNoticeSheet(context)),
            ),
            const SizedBox(height: 20),
            _HeroCard(userName: name, onStartConversation: onOpenConversations),
            const SizedBox(height: 14),
            _SnapchatUsernameCallCard(
              onOpenContacts: onOpenContacts ?? onOpenConversations,
            ),
            const SizedBox(height: 26),
            _SectionHeading(
              title: 'Choose a Tool',
              actionLabel: 'See all',
              onAction: onSignToTextTap,
            ),
            const SizedBox(height: 12),
            if (wide)
              Row(
                children: [
                  Expanded(
                    child: _ToolCard(
                      title: 'Sign to Text',
                      subtitle:
                          'Translate ISL gestures into text in real time.',
                      icon: Icons.back_hand_outlined,
                      color: SignTalkColors.primaryBlue,
                      tint: SignTalkColors.blueTint,
                      onTap: onSignToTextTap,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _ToolCard(
                      title: 'Speech to Text',
                      subtitle: 'Dictate and edit captions in real time.',
                      icon: Icons.mic_none_outlined,
                      color: const Color(0xFF0D9F76),
                      tint: const Color(0xFFE8FAF4),
                      onTap: onSpeechToTextTap,
                    ),
                  ),
                ],
              )
            else ...[
              _ToolCard(
                title: 'Sign to Text',
                subtitle: 'Translate ISL gestures into text in real time.',
                icon: Icons.back_hand_outlined,
                color: SignTalkColors.primaryBlue,
                tint: SignTalkColors.blueTint,
                onTap: onSignToTextTap,
              ),
              const SizedBox(height: 12),
              _ToolCard(
                title: 'Speech to Text',
                subtitle: 'Dictate and edit captions in real time.',
                icon: Icons.mic_none_outlined,
                color: const Color(0xFF0D9F76),
                tint: const Color(0xFFE8FAF4),
                onTap: onSpeechToTextTap,
              ),
            ],
            const SizedBox(height: 14),
            _ConversationCard(onTap: onOpenConversations),
            const SizedBox(height: 26),
            _SectionHeading(
              title: 'Quick Actions',
              actionLabel: 'See all',
              onAction: onProfileTap,
            ),
            const SizedBox(height: 12),
            _QuickActions(
              wide: wide,
              onContacts: onOpenContacts ?? onOpenConversations,
              onHistory: onOpenLogs ?? onOpenConversations,
              onLearn: onLearnTap ?? onSignToTextTap,
              onSettings: onProfileTap ?? onOpenConversations,
            ),
          ],
        );
      },
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.onProfileTap,
    required this.onNotificationsTap,
  });

  final VoidCallback? onProfileTap;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    final user = SignTalkScope.authOf(context).currentUser;
    final initials = _initials(user?.name ?? 'Demo User');
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: SignTalkColors.primaryBlue.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/signtalk-logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: const BoxDecoration(
                  color: SignTalkColors.primaryBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.back_hand_outlined,
                  color: Colors.white,
                  size: 25,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SignTalk',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                  color: SignTalkColors.primaryText,
                ),
              ),
              Text(
                'Bridging people. Breaking barriers.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: SignTalkColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
        _RoundIconButton(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Notifications',
          onTap: onNotificationsTap,
        ),
        const SizedBox(width: 8),
        Material(
          color: SignTalkColors.primaryBlue,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onProfileTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: SignTalkColors.card,
        shape: const CircleBorder(
          side: BorderSide(color: SignTalkColors.border),
        ),
        child: Semantics(
          button: true,
          label: tooltip,
          child: GestureDetector(
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, color: SignTalkColors.primaryText, size: 23),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.userName, required this.onStartConversation});

  final String userName;
  final VoidCallback onStartConversation;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF123FAE), Color(0xFF2F9BF4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x282563EB),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            const Positioned(
              right: -34,
              bottom: -55,
              child: _HeroIllustration(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 150, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      child: Text(
                        '✦  Welcome back, $userName!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Communication,\nwithout barriers.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      height: 1.06,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.9,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Use sign language, speech and text to connect with everyone.',
                    style: TextStyle(
                      color: Colors.white70,
                      height: 1.35,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: onStartConversation,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 19),
                    label: const Text('Connect now'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: SignTalkColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroIllustration extends StatelessWidget {
  const _HeroIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 205,
      height: 205,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
          ),
          const Icon(Icons.people_alt_rounded, size: 132, color: Colors.white),
          Positioned(
            top: 18,
            right: 8,
            child: _Bubble(icon: Icons.back_hand_rounded, label: 'Sign'),
          ),
          Positioned(
            bottom: 25,
            left: 4,
            child: _Bubble(icon: Icons.chat_rounded, label: 'Hello'),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [SignTalkColors.cardShadow],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: SignTalkColors.primaryBlue),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: SignTalkColors.primaryText,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: SignTalkColors.primaryText,
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: onAction,
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.chevron_right_rounded, size: 19),
          label: Text(actionLabel),
          style: TextButton.styleFrom(
            foregroundColor: SignTalkColors.primaryBlue,
            padding: EdgeInsets.zero,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.tint,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tint,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.12)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: SignTalkColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          height: 1.3,
                          color: SignTalkColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                _ArrowButton(color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF3F0FF),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C4EF5),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start a Conversation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: SignTalkColors.primaryText,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Connect using text, voice or sign language.',
                      style: TextStyle(color: SignTalkColors.secondaryText),
                    ),
                  ],
                ),
              ),
              const _ArrowButton(color: Color(0xFF6C4EF5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.wide,
    required this.onContacts,
    required this.onHistory,
    required this.onLearn,
    required this.onSettings,
  });

  final bool wide;
  final VoidCallback onContacts;
  final VoidCallback onHistory;
  final VoidCallback onLearn;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        Icons.people_alt_outlined,
        'Contacts',
        'Manage your contacts',
        onContacts,
        const Color(0xFFEAF2FF),
      ),
      (
        Icons.history_rounded,
        'History',
        'View past conversations',
        onHistory,
        const Color(0xFFF0EDFF),
      ),
      (
        Icons.menu_book_outlined,
        'Learn ISL',
        'Practice with tutorials',
        onLearn,
        const Color(0xFFFFF0DD),
      ),
      (
        Icons.settings_outlined,
        'Settings',
        'Customize your app',
        onSettings,
        const Color(0xFFF0F2F5),
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: wide ? 4 : 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: wide ? 1.15 : 1.25,
      ),
      itemBuilder: (context, index) {
        final action = actions[index];
        return Material(
          color: SignTalkColors.card,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: action.$4,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: action.$5,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      action.$1,
                      color: SignTalkColors.primaryBlue,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    action.$2,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: SignTalkColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    action.$3,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: SignTalkColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.chevron_right_rounded, color: color, size: 24),
    );
  }
}

class _SnapchatUsernameCallCard extends StatelessWidget {
  const _SnapchatUsernameCallCard({required this.onOpenContacts});

  final VoidCallback onOpenContacts;

  @override
  Widget build(BuildContext context) {
    int pendingCount = 0;
    try {
      pendingCount = SignTalkScope.contactsOf(context).pendingIncomingCount;
    } catch (_) {}

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFC00), Color(0xFFFFEB3B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpenContacts,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: Color(0xFFFFFC00),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Flexible(
                            child: Text(
                              'Find by Username & Call',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          if (pendingCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF3B30),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$pendingCount new',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Request @username access, accept, & call instantly',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Add',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 10,
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
}
