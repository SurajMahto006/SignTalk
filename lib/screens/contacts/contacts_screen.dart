import 'package:flutter/material.dart';

import '../../app/sign_talk_scope.dart';
import '../../services/contacts/contact_item.dart';
import '../../services/contacts/contacts_service.dart';
import '../../theme/sign_talk_colors.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({
    super.key,
    required this.onBack,
    required this.onOpenChat,
    required this.onOpenVideoCall,
  });

  final VoidCallback onBack;
  final ValueChanged<String> onOpenChat;
  final ValueChanged<String> onOpenVideoCall;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchFilter = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchFilter = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showAddContactSheet(BuildContext context, ContactsService service) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _AddContactModal(
        contactsService: service,
        onContactAccepted: (contactName) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎉 $contactName is now in your contacts!'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: SignTalkColors.successGreen,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contactsService = SignTalkScope.contactsOf(context);

    return Scaffold(
      backgroundColor: SignTalkColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(115),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: SignTalkColors.border, width: 1),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 16, 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          size: 20,
                          color: SignTalkColors.primaryBlue,
                        ),
                        tooltip: 'Back to Home',
                        onPressed: widget.onBack,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Contacts',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: SignTalkColors.primaryText,
                              ),
                            ),
                            Text(
                              '${contactsService.savedContacts.length} saved contacts',
                              style: const TextStyle(
                                fontSize: 12,
                                color: SignTalkColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () =>
                            _showAddContactSheet(context, contactsService),
                        icon: const Icon(Icons.person_add_alt_1, size: 17),
                        label: const Text('Add Contact'),
                        style: FilledButton.styleFrom(
                          backgroundColor: SignTalkColors.primaryBlue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  labelColor: SignTalkColors.primaryBlue,
                  unselectedLabelColor: SignTalkColors.secondaryText,
                  indicatorColor: SignTalkColors.primaryBlue,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Saved Contacts'),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: SignTalkColors.blueTint,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${contactsService.savedContacts.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: SignTalkColors.primaryBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Requests'),
                          if (contactsService.pendingIncomingCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF4D4F),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${contactsService.pendingIncomingCount}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSavedContactsTab(contactsService),
          _buildRequestsTab(contactsService),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddContactSheet(context, contactsService),
        backgroundColor: SignTalkColors.primaryBlue,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text(
          'Find Contact',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSavedContactsTab(ContactsService service) {
    final allContacts = service.savedContacts;
    final filtered = _searchFilter.isEmpty
        ? allContacts
        : allContacts.where((c) {
            return c.name.toLowerCase().contains(_searchFilter) ||
                c.username.toLowerCase().contains(_searchFilter) ||
                c.role.toLowerCase().contains(_searchFilter);
          }).toList();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search contacts by name or @username...',
              hintStyle: const TextStyle(
                color: SignTalkColors.secondaryText,
                fontSize: 14,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: SignTalkColors.secondaryText,
              ),
              suffixIcon: _searchFilter.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: SignTalkColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: SignTalkColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: SignTalkColors.primaryBlue,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),

        // Contacts List
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptySavedState(service)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final contact = filtered[index];
                    return _ContactCardItem(
                      contact: contact,
                      onTap: () => widget.onOpenChat(contact.name),
                      onChat: () => widget.onOpenChat(contact.name),
                      onVideoCall: () => widget.onOpenVideoCall(contact.name),
                      onDelete: () => _confirmRemoveContact(service, contact),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptySavedState(ContactsService service) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: SignTalkColors.blueTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline,
                size: 36,
                color: SignTalkColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchFilter.isEmpty
                  ? 'No contacts yet'
                  : 'No contacts matching "$_searchFilter"',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: SignTalkColors.primaryText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchFilter.isEmpty
                  ? 'Add your friends or search registered ISL signers to start conversations!'
                  : 'Try searching with a different username or name.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: SignTalkColors.secondaryText,
              ),
            ),
            const SizedBox(height: 16),
            if (_searchFilter.isEmpty)
              ElevatedButton.icon(
                onPressed: () => _showAddContactSheet(context, service),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Add Your First Contact'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SignTalkColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsTab(ContactsService service) {
    final incoming = service.incomingRequests;
    final outgoing = service.outgoingRequests;

    if (incoming.isEmpty && outgoing.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(
                  color: Color(0xFFF0EDFF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  size: 34,
                  color: Color(0xFF6C4EF5),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No pending requests',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: SignTalkColors.primaryText,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'When someone sends you a contact request, or when you send requests to others, they will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: SignTalkColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        if (incoming.isNotEmpty) ...[
          Row(
            children: [
              const Icon(
                Icons.inbox_outlined,
                size: 18,
                color: SignTalkColors.primaryBlue,
              ),
              const SizedBox(width: 8),
              Text(
                'Incoming Requests (${incoming.length})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: SignTalkColors.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...incoming.map(
            (req) => _IncomingRequestCard(
              request: req,
              onAccept: () async {
                await service.acceptRequest(req.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '✅ Accepted request! ${req.user.name} is now in your contacts.',
                      ),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: SignTalkColors.successGreen,
                    ),
                  );
                }
              },
              onDecline: () async {
                await service.declineRequest(req.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Request declined'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (outgoing.isNotEmpty) ...[
          Row(
            children: [
              const Icon(
                Icons.outbox_outlined,
                size: 18,
                color: Color(0xFFF59E0B),
              ),
              const SizedBox(width: 8),
              Text(
                'Sent Requests (${outgoing.length})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: SignTalkColors.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Waiting for the other person to accept. You can simulate their acceptance below to test the connection immediately!',
            style: TextStyle(
              fontSize: 12,
              color: SignTalkColors.secondaryText,
            ),
          ),
          const SizedBox(height: 12),
          ...outgoing.map(
            (req) => _OutgoingRequestCard(
              request: req,
              onCancel: () => service.cancelOutgoingRequest(req.id),
              onSimulateAccept: () async {
                await service.simulateAcceptOutgoingRequest(req.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '🎉 ${req.user.name} (@${req.user.username}) accepted your request! Now in your contacts.',
                      ),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: SignTalkColors.successGreen,
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ],
    );
  }

  void _confirmRemoveContact(ContactsService service, ContactItem contact) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${contact.name}?'),
        content: Text(
          'Are you sure you want to remove @${contact.username} from your contacts? You can always add them back later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              service.removeContact(contact.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Removed ${contact.name} from contacts'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: SignTalkColors.callRed,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

/// Card representing a saved contact with quick action buttons.
class _ContactCardItem extends StatelessWidget {
  const _ContactCardItem({
    required this.contact,
    required this.onTap,
    required this.onChat,
    required this.onVideoCall,
    required this.onDelete,
  });

  final ContactItem contact;
  final VoidCallback onTap;
  final VoidCallback onChat;
  final VoidCallback onVideoCall;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: SignTalkColors.border),
          ),
          child: Row(
            children: [
              // Avatar with online status
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _avatarColor(contact.name),
                    child: Text(
                      _initials(contact.name),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: contact.isOnline
                            ? SignTalkColors.successGreen
                            : const Color(0xFFBDC3C7),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Contact Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            contact.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: SignTalkColors.primaryText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: SignTalkColors.blueTint,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            contact.displayHandle,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: SignTalkColors.primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      contact.role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: contact.isOnline
                            ? const Color(0xFF0D9F76)
                            : SignTalkColors.secondaryText,
                        fontWeight: contact.isOnline
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Chat button
                  IconButton(
                    onPressed: onChat,
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: SignTalkColors.primaryBlue,
                      size: 21,
                    ),
                    tooltip: 'Start Chat',
                    style: IconButton.styleFrom(
                      backgroundColor: SignTalkColors.blueTint,
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(36, 36),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Video call button
                  IconButton(
                    onPressed: onVideoCall,
                    icon: const Icon(
                      Icons.videocam_outlined,
                      color: Color(0xFF6C4EF5),
                      size: 22,
                    ),
                    tooltip: 'Start Video Call',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF3F0FF),
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(36, 36),
                    ),
                  ),
                  const SizedBox(width: 2),

                  // More Menu (remove)
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      size: 19,
                      color: SignTalkColors.secondaryText,
                    ),
                    padding: EdgeInsets.zero,
                    onSelected: (val) {
                      if (val == 'delete') onDelete();
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              color: SignTalkColors.callRed,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Remove Contact',
                              style: TextStyle(color: SignTalkColors.callRed),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Incoming contact request card
class _IncomingRequestCard extends StatelessWidget {
  const _IncomingRequestCard({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  final ContactRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final user = request.user;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SignTalkColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _avatarColor(user.name),
                child: Text(
                  _initials(user.name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: SignTalkColors.primaryText,
                      ),
                    ),
                    Text(
                      '${user.displayHandle} • ${user.role}',
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
          if (user.bio.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: SignTalkColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                user.bio,
                style: const TextStyle(
                  fontSize: 12,
                  color: SignTalkColors.secondaryText,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDecline,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: SignTalkColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text(
                    'Decline',
                    style: TextStyle(
                      color: SignTalkColors.secondaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onAccept,
                  icon: const Icon(Icons.check, size: 17),
                  label: const Text('Accept'),
                  style: FilledButton.styleFrom(
                    backgroundColor: SignTalkColors.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Outgoing pending request card
class _OutgoingRequestCard extends StatelessWidget {
  const _OutgoingRequestCard({
    required this.request,
    required this.onCancel,
    required this.onSimulateAccept,
  });

  final ContactRequest request;
  final VoidCallback onCancel;
  final VoidCallback onSimulateAccept;

  @override
  Widget build(BuildContext context) {
    final user = request.user;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _avatarColor(user.name),
                child: Text(
                  _initials(user.name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: SignTalkColors.primaryText,
                      ),
                    ),
                    Text(
                      '${user.displayHandle} • Request Pending',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFD97706),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close,
                  size: 18,
                  color: SignTalkColors.secondaryText,
                ),
                tooltip: 'Cancel request',
                onPressed: onCancel,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFFD97706),
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Simulate ${''}: Opposite person accepts your request',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF92400E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onSimulateAccept,
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Accept Now',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal Bottom Sheet to search users and send contact requests
class _AddContactModal extends StatefulWidget {
  const _AddContactModal({
    required this.contactsService,
    required this.onContactAccepted,
  });

  final ContactsService contactsService;
  final ValueChanged<String> onContactAccepted;

  @override
  State<_AddContactModal> createState() => _AddContactModalState();
}

class _AddContactModalState extends State<_AddContactModal> {
  final TextEditingController _queryController = TextEditingController();
  List<ContactItem> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _searchResults = widget.contactsService.searchUsers('');
    _queryController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      _searchResults =
          widget.contactsService.searchUsers(_queryController.text);
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: SignTalkColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add New Contact',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: SignTalkColors.primaryText,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Search by username to send a connection request',
                        style: TextStyle(
                          fontSize: 12,
                          color: SignTalkColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
            child: TextField(
              controller: _queryController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Type username (e.g. @vikram_singh or ananya)...',
                hintStyle: const TextStyle(
                  color: SignTalkColors.secondaryText,
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.alternate_email,
                  color: SignTalkColors.primaryBlue,
                ),
                suffixIcon: _queryController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _queryController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: SignTalkColors.background,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Suggestion Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  'Suggested: ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: SignTalkColors.secondaryText,
                  ),
                ),
                ...['vikram_singh', 'ananya_k', 'kabir_das', 'tanvi_isl'].map(
                  (tag) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text('@$tag'),
                      labelStyle: const TextStyle(
                        fontSize: 11,
                        color: SignTalkColors.primaryBlue,
                        fontWeight: FontWeight.w700,
                      ),
                      backgroundColor: SignTalkColors.blueTint,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide.none,
                      ),
                      onPressed: () {
                        _queryController.text = tag;
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          const Divider(height: 1, color: SignTalkColors.border),

          // Search Results
          Expanded(
            child: _searchResults.isEmpty
                ? const Center(
                    child: Text(
                      'No users found',
                      style: TextStyle(color: SignTalkColors.secondaryText),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    itemCount: _searchResults.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final user = _searchResults[index];
                      final isAlreadyContact =
                          widget.contactsService.isContact(user.username);
                      final isPending = widget.contactsService
                          .isRequestPending(user.username);

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: SignTalkColors.border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: _avatarColor(user.name),
                              child: Text(
                                _initials(user.name),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: SignTalkColors.primaryText,
                                    ),
                                  ),
                                  Text(
                                    '${user.displayHandle} • ${user.role}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: SignTalkColors.secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isAlreadyContact) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8FAF4),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 14,
                                      color: Color(0xFF0D9F76),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Connected',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0D9F76),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (isPending) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.schedule,
                                      size: 14,
                                      color: Color(0xFFD97706),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Pending',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFD97706),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              FilledButton.icon(
                                onPressed: () async {
                                  await widget.contactsService
                                      .sendRequest(user);
                                  setState(() {});
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Connection request sent to ${user.displayHandle}!',
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                        action: SnackBarAction(
                                          label: 'Simulate Accept',
                                          textColor: Colors.yellowAccent,
                                          onPressed: () async {
                                            // Find outgoing request
                                            final req = widget.contactsService
                                                .outgoingRequests
                                                .firstWhere(
                                              (r) =>
                                                  r.user.username ==
                                                  user.username,
                                            );
                                            await widget.contactsService
                                                .simulateAcceptOutgoingRequest(
                                              req.id,
                                            );
                                            widget.onContactAccepted(user.name);
                                          },
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.send_rounded, size: 14),
                                label: const Text('Connect'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: SignTalkColors.primaryBlue,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

Color _avatarColor(String name) {
  final hash = name.codeUnits.fold(0, (acc, val) => acc + val);
  const colors = [
    Color(0xFF007AFF),
    Color(0xFF6C4EF5),
    Color(0xFF0D9F76),
    Color(0xFFE65100),
    Color(0xFFE91E63),
    Color(0xFF0288D1),
  ];
  return colors[hash % colors.length];
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return 'U';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}
