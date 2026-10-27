import 'package:flutter/material.dart';

import '../../app/sign_talk_scope.dart';
import '../../services/auth/auth_user.dart';
import '../../services/permissions/device_permission_status.dart';
import '../../theme/sign_talk_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.permissionStatus});

  final DevicePermissionStatus permissionStatus;

  @override
  Widget build(BuildContext context) {
    final prefs = SignTalkScope.preferencesOf(context);
    final auth = SignTalkScope.authOf(context);
    final user = auth.currentUser;

    return ListenableBuilder(
      listenable: Listenable.merge([prefs, permissionStatus, auth]),
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 24,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: SignTalkColors.primaryText,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Customize your SignTalk experience',
                        style: TextStyle(
                          fontSize: 14,
                          color: SignTalkColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: SignTalkColors.card,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: () => _showInfo(
                      context,
                      'Notifications',
                      'You are all caught up. SignTalk will show important permission and accessibility updates here.',
                    ),
                    customBorder: const CircleBorder(),
                    child: const SizedBox(
                      width: 42,
                      height: 42,
                      child: Icon(
                        Icons.notifications_none_rounded,
                        color: SignTalkColors.primaryText,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (prefs.loadError != null) ...[
              const SizedBox(height: 8),
              Text(
                prefs.loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: SignTalkColors.callRed,
                ),
              ),
            ],
            const SizedBox(height: 14),
            _ProfileCard(
              user: user,
              onTap: () => _showProfileDialog(context, user),
            ),
            const SizedBox(height: 14),
            _SettingsGroup(
              title: 'Accessibility',
              subtitle: 'Make the app comfortable for you',
              icon: Icons.accessibility_new,
              children: [
                _ChevronRow(
                  icon: Icons.format_size,
                  label: 'Text Size',
                  subtitle: 'Adjust text size for better readability',
                  value: prefs.textSize,
                  onTap: () async {
                    final next = switch (prefs.textSize) {
                      'Small' => 'Medium',
                      'Medium' => 'Large',
                      _ => 'Small',
                    };
                    await prefs.setTextSize(next);
                    prefs.triggerHapticIfEnabled();
                  },
                ),
                _SwitchRow(
                  icon: Icons.closed_caption_outlined,
                  label: 'Captions',
                  subtitle: 'Show captions in conversations',
                  value: prefs.captionsEnabled,
                  onChanged: (v) => prefs.setCaptionsEnabled(v),
                ),
                _SwitchRow(
                  icon: Icons.vibration,
                  label: 'Haptic Feedback',
                  subtitle: 'Get vibration feedback for actions',
                  value: prefs.hapticEnabled,
                  onChanged: (v) => prefs.setHapticEnabled(v),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsGroup(
              title: 'Language & Voice',
              subtitle: 'Choose your preferred languages and voice settings',
              icon: Icons.language,
              children: [
                _ChevronRow(
                  icon: Icons.back_hand_outlined,
                  label: 'Sign Language',
                  subtitle: 'Select your sign language',
                  value: 'ISL (Indian)',
                  onTap: () => _showInfo(
                    context,
                    'Sign language',
                    'ISL recognition is not available in this build. This label shows the planned default only.',
                  ),
                ),
                _ChevronRow(
                  icon: Icons.record_voice_over_outlined,
                  label: 'Speech Language',
                  subtitle: 'Language for speech to text',
                  value: prefs.speechLanguageLabel,
                  onTap: () => _pickSpeechLanguage(context, prefs),
                ),
                _SwitchRow(
                  icon: Icons.volume_up_outlined,
                  label: 'Spoken Output',
                  subtitle: 'Read out messages using text to speech',
                  value: prefs.spokenOutputEnabled,
                  onChanged: (v) => prefs.setSpokenOutputEnabled(v),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsGroup(
              title: 'Permissions',
              subtitle: 'Manage app permissions',
              icon: Icons.shield_outlined,
              children: [
                _StatusRow(
                  icon: Icons.photo_camera_outlined,
                  label: 'Camera Access',
                  subtitle: 'Used for video calls and sign detection',
                  status: permissionStatus.cameraStatusLabel(),
                  statusColor: _permissionColor(permissionStatus.cameraGranted),
                  onTap: () => _showInfo(
                    context,
                    'Camera permission',
                    permissionStatus.cameraDetail ?? 'Camera is requested when you tap Start Camera on Sign to Text. Status reflects your last attempt in this browser session.',
                  ),
                ),
                _StatusRow(
                  icon: Icons.mic_none_outlined,
                  label: 'Microphone Access',
                  subtitle: 'Used for speech to text',
                  status: permissionStatus.microphoneStatusLabel(),
                  statusColor: _permissionColor(
                    permissionStatus.microphoneGranted,
                  ),
                  onTap: () => _showInfo(
                    context,
                    'Microphone permission',
                    permissionStatus.microphoneDetail ?? 'Microphone is requested when you start speech recognition. Status reflects your last attempt in this browser session.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsGroup(
              title: 'Privacy & Support',
              subtitle: 'Your privacy, help and app information',
              icon: Icons.verified_user_outlined,
              children: [
                _ChevronRow(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy Policy',
                  subtitle: 'Read our privacy policy',
                  onTap: () => _showInfo(
                    context,
                    'Privacy Policy',
                    'SignTalk saves your unique User ID and UI preferences locally in browser storage. Conversation messages and captions stay in memory until you refresh.',
                  ),
                ),
                _ChevronRow(
                  icon: Icons.support_agent,
                  label: 'Help & Support',
                  subtitle: 'Get help or contact support',
                  onTap: () => _showInfo(
                    context,
                    'Help & Support',
                    'For accessibility questions, unique ID inquiries, or bug reports, contact your project team.',
                  ),
                ),
                _ChevronRow(
                  icon: Icons.info_outline,
                  label: 'About SignTalk',
                  subtitle: 'App version and information',
                  value: 'v1.0.0',
                  onTap: () => _showInfo(
                    context,
                    'About SignTalk',
                    'SignTalk web app — ISL-assisted communication UI with real browser speech and camera where supported. Sign recognition remains future work.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsGroup(
              title: 'Account & Session',
              subtitle: 'Manage your account details',
              icon: Icons.manage_accounts_outlined,
              children: [
                _ChevronRow(
                  icon: Icons.alternate_email,
                  label: 'Unique User ID',
                  subtitle: 'Your app user identifier',
                  value: user != null ? '@${user.userId}' : '@demo_user',
                  onTap: () => _showProfileDialog(context, user),
                ),
                _ChevronRow(
                  icon: Icons.badge_outlined,
                  label: 'Community Role',
                  subtitle: 'Your role in the community',
                  value: user?.role ?? 'ISL Signer',
                  onTap: () => _showProfileDialog(context, user),
                ),
                _LogoutRow(onTap: () => _confirmLogout(context)),
              ],
            ),
          ],
        );
      },
    );
  }

  Color _permissionColor(bool? granted) {
    return switch (granted) {
      true => SignTalkColors.successGreen,
      false => SignTalkColors.callRed,
      null => SignTalkColors.secondaryText,
    };
  }

  Future<void> _pickSpeechLanguage(BuildContext context, prefs) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Speech language'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'en_US|English (US)'),
            child: const Text('English (US)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'en_IN|English (India)'),
            child: const Text('English (India)'),
          ),
        ],
      ),
    );
    if (picked == null || !context.mounted) return;
    final parts = picked.split('|');
    await prefs.setSpeechLanguage(label: parts[1], locale: parts[0]);
    if (!context.mounted) return;
    SignTalkScope.of(context).speechRecognition.setLocale(parts[0]);
  }

  void _showInfo(BuildContext context, String title, String body) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            if (title == 'About SignTalk') ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/signtalk-logo.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Text(title),
          ],
        ),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showProfileDialog(BuildContext context, AuthUser? user) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: SignTalkColors.primaryBlue,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                _getInitials(user?.name ?? 'Demo User'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text('User Profile'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProfileDetailItem(
              label: 'Full Name',
              value: user?.name ?? 'Demo User',
            ),
            const SizedBox(height: 10),
            _ProfileDetailItem(
              label: 'Unique User ID',
              value: '@${user?.userId ?? 'demo_user'}',
            ),
            const SizedBox(height: 10),
            _ProfileDetailItem(
              label: 'Role',
              value: user?.role ?? 'ISL Communicator',
            ),
            if (user?.email != null && user!.email.isNotEmpty) ...[
              const SizedBox(height: 10),
              _ProfileDetailItem(label: 'Email', value: user.email),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: SignTalkColors.tintBlue,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: SignTalkColors.tintBlueBorder),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.verified,
                    size: 16,
                    color: SignTalkColors.primaryBlue,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Verified Unique ID Account',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: SignTalkColors.primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text(
          'Are you sure you want to log out of SignTalk? You will need your User ID and password to sign back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: SignTalkColors.callRed,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && context.mounted) {
      await SignTalkScope.authOf(context).logout();
    }
  }

  static String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'ST';
  }
}

class _ProfileDetailItem extends StatelessWidget {
  const _ProfileDetailItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: SignTalkColors.secondaryText,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: SignTalkColors.primaryText,
          ),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user, required this.onTap});

  final AuthUser? user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayName = user?.name ?? 'Demo User';
    final userHandle = '@${user?.userId ?? 'demo_user'}';
    final role = user?.role ?? 'ISL Communicator';
    final initials = SettingsScreen._getInitials(displayName);

    return Material(
      color: SignTalkColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Colors.white, Color(0xFFE8F2FF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            border: Border.all(color: SignTalkColors.border),
            boxShadow: const [SignTalkColors.cardShadow],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: SignTalkColors.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: SignTalkColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        userHandle,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: SignTalkColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 5),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: SignTalkColors.tintBlue,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text(
                            role,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: SignTalkColors.primaryBlue,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFFA1A1A6),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SignTalkColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SignTalkColors.border),
        boxShadow: const [SignTalkColors.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                _SettingIcon(icon: icon, tint: SignTalkColors.tintBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: SignTalkColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: SignTalkColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _ChevronRow extends StatelessWidget {
  const _ChevronRow({
    required this.icon,
    required this.label,
    this.subtitle,
    this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SettingsRowShell(
      onTap: onTap,
      child: Row(
        children: [
          _SettingIcon(icon: icon, tint: SignTalkColors.purpleTint),
          const SizedBox(width: 10),
          Expanded(
            child: _SettingText(label: label, subtitle: subtitle),
          ),
          if (value != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                value!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
              ),
            ),
          ],
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 16, color: Color(0xFFC7C7CC)),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.status,
    required this.statusColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final String status;
  final Color statusColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SettingsRowShell(
      onTap: onTap,
      child: Row(
        children: [
          _SettingIcon(icon: icon, tint: SignTalkColors.purpleTint),
          const SizedBox(width: 10),
          Expanded(
            child: _SettingText(label: label, subtitle: subtitle),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 16, color: Color(0xFFC7C7CC)),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsRowShell(
      child: Row(
        children: [
          _SettingIcon(icon: icon, tint: SignTalkColors.greenTint),
          const SizedBox(width: 10),
          Expanded(
            child: _SettingText(label: label, subtitle: subtitle),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: SignTalkColors.primaryBlue.withValues(alpha: 0.5),
            activeThumbColor: SignTalkColors.primaryBlue,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _LogoutRow extends StatelessWidget {
  const _LogoutRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SettingsRowShell(
      onTap: onTap,
      child: const Row(
        children: [
          Icon(Icons.logout, size: 18, color: SignTalkColors.callRed),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Log Out of SignTalk',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: SignTalkColors.callRed,
              ),
            ),
          ),
          Icon(Icons.chevron_right, size: 16, color: SignTalkColors.callRed),
        ],
      ),
    );
  }
}

class _SettingsRowShell extends StatelessWidget {
  const _SettingsRowShell({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: child,
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: SignTalkColors.dividerLight)),
      ),
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(onTap: onTap, child: content),
            ),
    );
  }
}

class _SettingText extends StatelessWidget {
  const _SettingText({required this.label, this.subtitle});

  final String label;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: SignTalkColors.primaryText,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: SignTalkColors.secondaryText,
            ),
          ),
        ],
      ],
    );
  }
}

class _SettingIcon extends StatelessWidget {
  const _SettingIcon({required this.icon, required this.tint});

  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(11),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 19, color: SignTalkColors.primaryBlue),
    );
  }
}
