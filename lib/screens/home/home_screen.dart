import 'package:flutter/material.dart';

import '../../theme/sign_talk_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onSignToTextTap,
    required this.onSpeechToTextTap,
    required this.onOpenConversations,
  });

  final VoidCallback onSignToTextTap;
  final VoidCallback onSpeechToTextTap;
  final VoidCallback onOpenConversations;

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
        _HomeHeader(onProfileTap: () => _showComingSoon(context, 'Profile')),
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
                iconBackground: SignTalkColors.speechPurpleBg,
                iconColor: SignTalkColors.speechPurple,
                icon: Icons.mic_none_outlined,
                title: 'Speech to Text',
                subtitle: 'Turn spoken words\ninto readable captions.',
                onTap: onSpeechToTextTap,
              ),
              const SizedBox(height: 14),
              _ConversationBar(onTap: onOpenConversations),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _RecentActivitySection(),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onProfileTap});

  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
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
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(Icons.person_outline, size: 22, color: SignTalkColors.primaryText),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            boxShadow: const [SignTalkColors.cardShadow],
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

class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Activity', style: Theme.of(context).textTheme.titleSmall),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: SignTalkColors.primaryBlue,
                ),
                child: Text(
                  'View all',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: SignTalkColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SignTalkColors.border),
              boxShadow: const [SignTalkColors.cardShadow],
            ),
            child: Column(
              children: [
                _ActivityRow(
                  iconBackground: SignTalkColors.primaryBlue,
                  iconColor: Colors.white,
                  icon: Icons.back_hand_outlined,
                  title: 'Hello',
                  subtitle: 'Sign to Text • 2 mins ago',
                ),
                Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
                _ActivityRow(
                  iconBackground: SignTalkColors.speechPurpleBg,
                  iconColor: SignTalkColors.speechPurple,
                  icon: Icons.mic_none_outlined,
                  title: 'How are you?',
                  subtitle: 'Speech to Text • 15 mins ago',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.iconBackground,
    required this.iconColor,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final Color iconBackground;
  final Color iconColor;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: iconBackground, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        color: SignTalkColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: SignTalkColors.chevron, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
