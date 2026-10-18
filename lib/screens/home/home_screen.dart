import 'package:flutter/material.dart';

import '../../app/sign_talk_scope.dart';
import '../../theme/sign_talk_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onSignToTextTap,
    required this.onSpeechToTextTap,
    required this.onOpenConversations,
    this.onProfileTap,
  });

  final VoidCallback onSignToTextTap;
  final VoidCallback onSpeechToTextTap;
  final VoidCallback onOpenConversations;
  final VoidCallback? onProfileTap;

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — coming in a future update'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        _HomeHeader(onProfileTap: onProfileTap ?? () => _showComingSoon(context, 'Profile')),
        const SizedBox(height: 4),
        const _HeroSection(),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              _ActionCard(
                iconBackground: SignTalkColors.primaryBlue,
                iconColor: Colors.white,
                icon: Icons.back_hand_outlined,
                title: 'Sign to Text',
                subtitle: 'Translate ISL gestures\ninto text.',
                onTap: onSignToTextTap,
              ),
              const SizedBox(height: 14),
              _ActionCard(
                iconBackground: SignTalkColors.tintBlue,
                iconColor: SignTalkColors.primaryBlue,
                icon: Icons.mic_none_outlined,
                title: 'Speech to Text',
                subtitle: 'Dictate and edit\ncaptions in real time.',
                onTap: onSpeechToTextTap,
              ),
              const SizedBox(height: 16),
              _ConversationBar(onTap: onOpenConversations),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onProfileTap});

  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final user = SignTalkScope.authOf(context).currentUser;
    final initials = user != null && user.name.isNotEmpty
        ? (user.name.trim().split(RegExp(r'\s+')).length >= 2
            ? '${user.name.trim().split(RegExp(r'\s+'))[0][0]}${user.name.trim().split(RegExp(r'\s+'))[1][0]}'
            : user.name.substring(0, user.name.length >= 2 ? 2 : 1))
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Row(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: SignTalkColors.primaryBlue,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Icon(Icons.back_hand_outlined, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'SignTalk',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: SignTalkColors.primaryText,
                ),
              ),
            ],
          ),
          const Spacer(),
          Material(
            color: SignTalkColors.card,
            shape: CircleBorder(
              side: BorderSide(color: SignTalkColors.border),
            ),
            elevation: 0,
            shadowColor: Colors.black.withValues(alpha: 0.06),
            child: InkWell(
              onTap: onProfileTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 36,
                height: 36,
                child: initials != null
                    ? Center(
                        child: Text(
                          initials.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: SignTalkColors.primaryBlue,
                          ),
                        ),
                      )
                    : const Icon(Icons.person_outline, size: 22, color: SignTalkColors.primaryText),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    final user = SignTalkScope.authOf(context).currentUser;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: SignTalkColors.tintBlue,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: SignTalkColors.tintBlueBorder),
              ),
              child: Text(
                'Welcome, ${user.name} (@${user.userId})',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SignTalkColors.primaryBlue,
                ),
              ),
            ),
          ],
          Text(
            'Communication,\nwithout barriers.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            "Choose how you'd like to connect today.",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.iconBackground,
    required this.iconColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Color iconBackground;
  final Color iconColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SignTalkColors.card,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SignTalkColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: iconBackground,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Icon(icon, color: iconColor, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: SignTalkColors.chevron, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationBar extends StatelessWidget {
  const _ConversationBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SignTalkColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SignTalkColors.border),
            boxShadow: const [SignTalkColors.cardShadow],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: SignTalkColors.blueTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat_bubble, size: 16, color: SignTalkColors.primaryBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Start a Conversation',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 14),
                  ),
                ),
                const Icon(Icons.chevron_right, color: SignTalkColors.primaryBlue, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

