import 'package:flutter/material.dart';

import '../app/sign_talk_scope.dart';
import '../screens/conversations/conversations_screen.dart';
import '../screens/conversations/video_call_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/translate/sign_to_text_screen.dart';
import '../screens/translate/speech_to_text_screen.dart';
import '../services/permissions/device_permission_status.dart';
import '../theme/sign_talk_colors.dart';

enum _TranslateScreen { signToText, speechToText }

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.permissionStatus});

  final DevicePermissionStatus permissionStatus;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  _TranslateScreen _translateScreen = _TranslateScreen.signToText;
  bool _videoCallOpen = false;
  int _conversationsSession = 0;

  static const _tabLabels = ['Home', 'Translate', 'Conversations', 'Settings'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SignTalkColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Column(
              children: [
                Expanded(
                  child: _videoCallOpen
                      ? VideoCallScreen(onClose: () => setState(() => _videoCallOpen = false))
                      : _buildTabBody(),
                ),
                if (!_videoCallOpen)
                  _SignTalkBottomNav(
                    selectedIndex: _selectedIndex,
                    onSelected: _onTabSelected,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onTabSelected(int index) {
    setState(() {
      if (index == 1 && _selectedIndex != 1) {
        _translateScreen = _TranslateScreen.signToText;
      }
      _selectedIndex = index;
    });
  }

  void _openSignToText() {
    setState(() {
      _selectedIndex = 1;
      _translateScreen = _TranslateScreen.signToText;
    });
  }

  void _openSpeechToText() {
    setState(() {
      _selectedIndex = 1;
      _translateScreen = _TranslateScreen.speechToText;
    });
  }

  void _goHome() => setState(() => _selectedIndex = 0);

  void _openConversations() => setState(() => _selectedIndex = 2);

  void _openVideoCall() => setState(() {
        _selectedIndex = 2;
        _videoCallOpen = true;
      });

  void _sendTextToConversations(
    String text, {
    bool asSpoken = false,
    bool asRecognizedSign = false,
  }) {
    SignTalkScope.of(context).conversationDraft.stage(
          text,
          asSpoken: asSpoken,
          asRecognizedSign: asRecognizedSign,
        );
    setState(() {
      _selectedIndex = 2;
      _conversationsSession++;
    });
  }

  Widget _buildTabBody() {
    return switch (_selectedIndex) {
      0 => HomeScreen(
          onSignToTextTap: _openSignToText,
          onSpeechToTextTap: _openSpeechToText,
          onOpenConversations: _openConversations,
        ),
      1 => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TranslateModeBar(
              signSelected: _translateScreen == _TranslateScreen.signToText,
              onSign: () => setState(() => _translateScreen = _TranslateScreen.signToText),
              onSpeech: () => setState(() => _translateScreen = _TranslateScreen.speechToText),
            ),
            Expanded(
              child: switch (_translateScreen) {
                _TranslateScreen.signToText => SignToTextScreen(
                    onBack: _goHome,
                    onSendToConversations: (text, {asRecognizedSign = false}) =>
                        _sendTextToConversations(text, asRecognizedSign: asRecognizedSign),
                  ),
                _TranslateScreen.speechToText => SpeechToTextScreen(
                    onBack: _goHome,
                    onSendToConversations: (text) => _sendTextToConversations(text, asSpoken: true),
                  ),
              },
            ),
          ],
        ),
      2 => ConversationsScreen(
          key: ValueKey(_conversationsSession),
          onOpenVideoCall: _openVideoCall,
        ),
      3 => SettingsScreen(permissionStatus: widget.permissionStatus),
      _ => _TabPlaceholder(title: _tabLabels[_selectedIndex]),
    };
  }
}

class _TranslateModeBar extends StatelessWidget {
  const _TranslateModeBar({
    required this.signSelected,
    required this.onSign,
    required this.onSpeech,
  });

  final bool signSelected;
  final VoidCallback onSign;
  final VoidCallback onSpeech;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: SignTalkColors.dividerLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SignTalkColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              Expanded(
                child: _SegmentChip(
                  label: 'Sign to Text',
                  selected: signSelected,
                  onTap: onSign,
                ),
              ),
              Expanded(
                child: _SegmentChip(
                  label: 'Speech to Text',
                  selected: !signSelected,
                  onTap: onSpeech,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentChip extends StatelessWidget {
  const _SegmentChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? SignTalkColors.card : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      elevation: selected ? 0.5 : 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? SignTalkColors.primaryText : SignTalkColors.secondaryText,
            ),
          ),
        ),
      ),
    );
  }
}

class _TabPlaceholder extends StatelessWidget {
  const _TabPlaceholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction_outlined,
            size: 48,
            color: SignTalkColors.secondaryText.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 20),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'This screen will be implemented in a later task.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SignTalkBottomNav extends StatelessWidget {
  const _SignTalkBottomNav({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: SignTalkColors.card,
        border: Border(top: BorderSide(color: SignTalkColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              label: 'Home',
              icon: Icons.home,
              selectedIcon: Icons.home,
              filledWhenSelected: true,
              selected: selectedIndex == 0,
              onTap: () => onSelected(0),
            ),
            _NavItem(
              label: 'Translate',
              icon: Icons.translate_outlined,
              selectedIcon: Icons.translate,
              selected: selectedIndex == 1,
              onTap: () => onSelected(1),
            ),
            _NavItem(
              label: 'Conversations',
              icon: Icons.chat_bubble_outline,
              selectedIcon: Icons.chat_bubble,
              selected: selectedIndex == 2,
              onTap: () => onSelected(2),
            ),
            _NavItem(
              label: 'Settings',
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings,
              selected: selectedIndex == 3,
              onTap: () => onSelected(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
    this.filledWhenSelected = false,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;
  final bool filledWhenSelected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? SignTalkColors.primaryBlue : SignTalkColors.secondaryText;
    final iconData = selected ? selectedIcon : icon;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                iconData,
                size: 22,
                color: color,
                fill: selected && filledWhenSelected ? 1.0 : 0.0,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
