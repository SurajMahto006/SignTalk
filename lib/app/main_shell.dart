import 'dart:async';

import 'package:flutter/material.dart';

import 'sign_talk_scope.dart';
import '../screens/conversations/contact_list_screen.dart';
import '../screens/conversations/conversations_screen.dart';
import '../screens/conversations/video_call_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/learn/learn_isl_screen.dart';
import '../screens/logs/logs_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/translate/sign_to_text_screen.dart';
import '../screens/translate/speech_to_text_screen.dart';
import '../services/auth/auth_service.dart';
import '../services/permissions/device_permission_status.dart';
import '../theme/sign_talk_colors.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.permissionStatus});

  final DevicePermissionStatus permissionStatus;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  bool _videoCallOpen = false;
  String? _activeTool;
  int _conversationsSession = 0;
  String _contactName = 'Demo contact';
  bool _threadOpen = false;
  bool _threadBackToHome = true;

  static const _tabLabels = ['Home', 'Logs', 'Conversations', 'Settings'];

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    // Fill the Android width. Wider windows are already framed to a phone column.
    final appWidth = viewportWidth;
    return Scaffold(
      backgroundColor: SignTalkColors.background,
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: appWidth,
            child: DecoratedBox(
              decoration: const BoxDecoration(color: SignTalkColors.background),
              child: Column(
                children: [
                  Expanded(
                    child: _videoCallOpen
                        ? VideoCallScreen(
                            contactName: _contactName,
                            onClose: () =>
                                setState(() => _videoCallOpen = false),
                          )
                        : _activeTool == 'sign'
                        ? SignToTextScreen(
                            onBack: _closeTool,
                            onOpenSettings: _openSettings,
                            onSendToConversations: _sendSignTextToConversation,
                          )
                        : _activeTool == 'learn'
                        ? LearnIslScreen(onBack: _closeTool)
                        : _activeTool == 'speech'
                        ? SpeechToTextScreen(
                            onBack: _closeTool,
                            onOpenSettings: _openSettings,
                            onSendToConversations:
                                _sendSpeechTextToConversation,
                          )
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
      ),
    );
  }

  void _onTabSelected(int index) {
    setState(() {
      _activeTool = null;
      _selectedIndex = index;
      if (index == 2) _threadOpen = false;
    });
  }

  void _goHome() => setState(() {
    _activeTool = null;
    _selectedIndex = 0;
  });

  void _openConversations() => setState(() {
    _activeTool = null;
    _selectedIndex = 2;
    _threadOpen = true;
    _threadBackToHome = true;
  });

  void _openSettings() => setState(() {
    _activeTool = null;
    _selectedIndex = 3;
  });

  void _openSignToText() => setState(() => _activeTool = 'sign');

  void _openLearnIsl() => setState(() => _activeTool = 'learn');

  void _openContactList() => setState(() {
    _activeTool = null;
    _selectedIndex = 2;
    _threadOpen = false;
  });

  void _openSpeechToText() => setState(() => _activeTool = 'speech');

  void _closeTool() => setState(() => _activeTool = null);

  void _sendSignTextToConversation(
    String text, {
    bool asRecognizedSign = false,
  }) {
    SignTalkScope.of(context).conversationDraft
        .stage(text, asRecognizedSign: asRecognizedSign);
    setState(() {
      _activeTool = null;
      _selectedIndex = 2;
      _threadOpen = true;
      _threadBackToHome = true;
    });
  }

  void _sendSpeechTextToConversation(String text) {
    SignTalkScope.of(context).conversationDraft.stage(text, asSpoken: true);
    setState(() {
      _activeTool = null;
      _selectedIndex = 2;
      _threadOpen = true;
      _threadBackToHome = true;
    });
  }

  void _openVideoCall() => setState(() {
    _activeTool = null;
    _selectedIndex = 2;
    _videoCallOpen = true;
  });

  void _openContactConversation(String contactName) {
    final ownerId =
        SignTalkScope.authOf(context).currentUser?.userId ??
        AuthService.demoUserId;
    unawaited(
      SignTalkScope.of(context).contacts.ensure(
        ownerId: ownerId,
        name: contactName,
      ),
    );
    setState(() {
      _contactName = contactName;
      _selectedIndex = 2;
      _threadOpen = true;
      _threadBackToHome = false;
      _conversationsSession++;
    });
  }

  void _closeThread() => setState(() => _threadOpen = false);

  Widget _buildTabBody() {
    return switch (_selectedIndex) {
      0 => HomeScreen(
        onSignToTextTap: _openSignToText,
        onSpeechToTextTap: _openSpeechToText,
        onOpenConversations: _openConversations,
        onManageContacts: _openContactList,
        onOpenLogs: () => _onTabSelected(1),
        onLearnIsl: _openLearnIsl,
        onProfileTap: _openSettings,
      ),
      1 => LogsScreen(onOpenConversation: _openContactConversation),
      2 => _threadOpen
          ? ConversationsScreen(
              key: ValueKey(_conversationsSession),
              contactName: _contactName,
              onOpenVideoCall: _openVideoCall,
              onBack: _threadBackToHome ? _goHome : _closeThread,
              backTooltip: _threadBackToHome
                  ? 'Back to Home'
                  : 'Back to contacts',
            )
          : ContactListScreen(onOpenContact: _openContactConversation),
      3 => SettingsScreen(permissionStatus: widget.permissionStatus),
      _ => _TabPlaceholder(title: _tabLabels[_selectedIndex]),
    };
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
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontSize: 20),
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
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: _NavItem(
              label: 'Home',
              icon: Icons.home,
              selectedIcon: Icons.home,
              filledWhenSelected: true,
              selected: selectedIndex == 0,
              onTap: () => onSelected(0),
            ),
            ),
            Expanded(
              child: _NavItem(
              label: 'Logs',
              icon: Icons.history_outlined,
              selectedIcon: Icons.history,
              selected: selectedIndex == 1,
              onTap: () => onSelected(1),
            ),
            ),
            Expanded(
              child: _NavItem(
              label: 'Conversations',
              icon: Icons.chat_bubble_outline,
              selectedIcon: Icons.chat_bubble,
              selected: selectedIndex == 2,
              onTap: () => onSelected(2),
            ),
            ),
            Expanded(
              child: _NavItem(
              label: 'Settings',
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings,
              selected: selectedIndex == 3,
              onTap: () => onSelected(3),
            ),
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
    final color = selected
        ? SignTalkColors.primaryBlue
        : SignTalkColors.secondaryText;
    final iconData = selected ? selectedIcon : icon;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: double.infinity,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
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
