import 'package:flutter/material.dart';

import '../../app/sign_talk_scope.dart';
import '../../services/permissions/device_permission_status.dart';
import '../../theme/sign_talk_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.permissionStatus});

  final DevicePermissionStatus permissionStatus;

  @override
  Widget build(BuildContext context) {
    final prefs = SignTalkScope.preferencesOf(context);

    return ListenableBuilder(
      listenable: Listenable.merge([prefs, permissionStatus]),
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          children: [
            const Center(
              child: Text(
                'Settings',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: SignTalkColors.primaryText),
              ),
            ),
            if (prefs.loadError != null) ...[
              const SizedBox(height: 8),
              Text(
                prefs.loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: SignTalkColors.callRed),
              ),
            ],
            const SizedBox(height: 12),
            _ProfileCard(onTap: () => _showInfo(context, 'Demo profile', 'This is placeholder profile data for the SignTalk UI prototype.')),
            const SizedBox(height: 14),
            _SettingsGroup(
              title: 'Accessibility',
              icon: Icons.accessibility_new,
              children: [
                _ChevronRow(
                  icon: Icons.format_size,
                  label: 'Text Size',
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
                  value: prefs.captionsEnabled,
                  onChanged: (v) => prefs.setCaptionsEnabled(v),
                ),
                _SwitchRow(
                  icon: Icons.vibration,
                  label: 'Haptic Feedback',
                  value: prefs.hapticEnabled,
                  onChanged: (v) => prefs.setHapticEnabled(v),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsGroup(
              title: 'Language & Voice',
              icon: Icons.language,
              children: [
                _ChevronRow(
                  icon: Icons.back_hand_outlined,
                  label: 'Sign Language',
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
                  value: prefs.speechLanguageLabel,
                  onTap: () => _pickSpeechLanguage(context, prefs),
                ),
                _SwitchRow(
                  icon: Icons.volume_up_outlined,
                  label: 'Spoken Output',
                  value: prefs.spokenOutputEnabled,
                  onChanged: (v) => prefs.setSpokenOutputEnabled(v),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsGroup(
              title: 'Permissions',
              icon: Icons.shield_outlined,
              children: [
                _StatusRow(
                  icon: Icons.photo_camera_outlined,
                  label: 'Camera Access',
                  status: permissionStatus.cameraStatusLabel(),
                  statusColor: _permissionColor(permissionStatus.cameraGranted),
                  onTap: () => _showInfo(
                    context,
                    'Camera permission',
                    permissionStatus.cameraDetail ??
                        'Camera is requested when you tap Start Camera on Sign to Text. Status reflects your last attempt in this browser session.',
                  ),
                ),
                _StatusRow(
                  icon: Icons.mic_none_outlined,
                  label: 'Microphone Access',
                  status: permissionStatus.microphoneStatusLabel(),
                  statusColor: _permissionColor(permissionStatus.microphoneGranted),
                  onTap: () => _showInfo(
                    context,
                    'Microphone permission',
                    permissionStatus.microphoneDetail ??
                        'Microphone is requested when you start speech recognition. Status reflects your last attempt in this browser session.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsGroup(
              title: 'Privacy & Support',
              icon: Icons.verified_user_outlined,
              children: [
                _ChevronRow(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy Policy',
                  onTap: () => _showInfo(
                    context,
                    'Privacy Policy',
                    'SignTalk saves only UI preferences in local browser storage. Conversation messages and captions stay in memory until you refresh. No cloud sync or encryption is implemented.',
                  ),
                ),
                _ChevronRow(
                  icon: Icons.support_agent,
                  label: 'Help & Support',
                  onTap: () => _showInfo(
                    context,
                    'Help & Support',
                    'For accessibility questions or bug reports, contact your project team. In-app support channels are not wired up yet.',
                  ),
                ),
                _ChevronRow(
                  icon: Icons.info_outline,
                  label: 'About SignTalk',
                  value: 'v1.0.0',
                  onTap: () => _showInfo(
                    context,
                    'About SignTalk',
                    'SignTalk web app — ISL-assisted communication UI with real browser speech and camera where supported. Sign recognition remains future work.',
                  ),
                ),
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
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SignTalkColors.card,
      borderRadius: BorderRadius.circular(16),
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
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(color: SignTalkColors.primaryBlue, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const Text('DU', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Demo User', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: SignTalkColors.primaryText)),
                      SizedBox(height: 2),
                      Text('SignTalk User (demo)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: SignTalkColors.secondaryText)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFFA1A1A6), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.icon, required this.children});

  final String title;
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
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Row(
              children: [
                Icon(icon, size: 18, color: SignTalkColors.primaryBlue),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: SignTalkColors.primaryText)),
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
    this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SettingsRowShell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: SignTalkColors.secondaryText),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5, color: SignTalkColors.primaryText))),
          if (value != null) Text(value!, style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
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
    required this.status,
    required this.statusColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String status;
  final Color statusColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SettingsRowShell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: SignTalkColors.secondaryText),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5, color: SignTalkColors.primaryText))),
          Text(status, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: statusColor)),
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
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsRowShell(
      child: Row(
        children: [
          Icon(icon, size: 18, color: SignTalkColors.secondaryText),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5, color: SignTalkColors.primaryText))),
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

class _SettingsRowShell extends StatelessWidget {
  const _SettingsRowShell({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: child);
    return DecoratedBox(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: SignTalkColors.dividerLight))),
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(onTap: onTap, child: content),
            ),
    );
  }
}
