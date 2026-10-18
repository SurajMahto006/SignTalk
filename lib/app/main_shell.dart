import 'package:flutter/material.dart';

import '../screens/conversations/conversations_screen.dart';
import '../screens/conversations/video_call_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/logs/logs_screen.dart';
import '../screens/settings/settings_screen.dart';
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
  int _conversationsSession = 0;
  String _contactName = 'Demo contact';

  static const _tabLabels = ['Home', 'Logs', 'Conversations', 'Settings'];

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final appWidth = viewportWidth < 390
        ? viewportWidth
        : (viewportWidth < 760 ? 520.0 : 640.0);
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
      _selectedIndex = index;
    });
  }

  void _openConversation() => setState(() => _selectedIndex = 2);

  void _goHome() => setState(() => _selectedIndex = 0);

  void _openConversations() => setState(() => _selectedIndex = 2);

  void _openSettings() => setState(() => _selectedIndex = 3);

  void _openVideoCall() => setState(() {
    _selectedIndex = 2;
    _videoCallOpen = true;
  });

  void _openContactConversation(String contactName) {
    setState(() {
      _contactName = contactName;
      _selectedIndex = 2;
      _conversationsSession++;
    });
  }

  Widget _buildTabBody() {
    return switch (_selectedIndex) {
      0 => HomeScreen(
        onSignToTextTap: _openConversation,
        onSpeechToTextTap: _openConversation,
        onOpenConversations: _openConversations,
        onProfileTap: _openSettings,
      ),
      1 => LogsScreen(onOpenConversation: _openContactConversation),
      2 => ConversationsScreen(
        key: ValueKey(_conversationsSession),
        contactName: _contactName,
        onOpenVideoCall: _openVideoCall,
        onBack: _goHome,
      ),
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
              label: 'Logs',
              icon: Icons.history_outlined,
              selectedIcon: Icons.history,
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
          width: 70,
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
