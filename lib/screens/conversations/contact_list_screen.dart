import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/sign_talk_scope.dart';
import '../../services/auth/auth_service.dart';
import '../../services/communication/contact_book.dart';
import '../../theme/sign_talk_colors.dart';

class ContactListScreen extends StatefulWidget {
  const ContactListScreen({super.key, required this.onOpenContact});

  final ValueChanged<String> onOpenContact;

  @override
  State<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends State<ContactListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final scope = SignTalkScope.of(context);
    final ownerId =
        scope.authService.currentUser?.userId ?? AuthService.demoUserId;
    final contacts = ContactBook.matching(
      scope.contacts.contactsFor(ownerId),
      _query,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Conversations',
                      style: TextStyle(
                        fontSize: 24,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: SignTalkColors.primaryText,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Choose a person, or add someone new.',
                      style: TextStyle(
                        fontSize: 14,
                        color: SignTalkColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: SignTalkColors.primaryBlue,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () => unawaited(_addContact(context, ownerId)),
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(Icons.person_add_alt_1, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: 'Search contacts',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: contacts.isEmpty
              ? Center(
                  child: Text(
                    _query.trim().isEmpty
                        ? 'No contacts yet. Add someone to start a chat.'
                        : 'No contact matches that search.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: SignTalkColors.secondaryText),
                  ),
                )
              : ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            itemCount: contacts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final name = contacts[index];
              final messages = scope.conversations.messagesFor(
                ownerId: ownerId,
                contactName: name,
              );
              final preview = messages.isEmpty
                  ? 'No messages yet'
                  : messages.last.body;
              return Material(
                color: SignTalkColors.card,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => widget.onOpenContact(name),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: SignTalkColors.primaryBlue,
                          child: Text(
                            name.trim().isEmpty
                                ? '?'
                                : name.trim()[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                preview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: SignTalkColors.secondaryText,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Rename $name',
                          onPressed: () => unawaited(
                            _renameContact(context, ownerId, name),
                          ),
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: SignTalkColors.secondaryText,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove $name',
                          onPressed: () => unawaited(
                            _removeContact(context, ownerId, name),
                          ),
                          icon: const Icon(
                            Icons.close,
                            color: SignTalkColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _addContact(BuildContext context, String ownerId) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add a contact'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Name'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || !context.mounted) return;
    final error = await SignTalkScope.of(context).contacts.add(
      ownerId: ownerId,
      name: name,
    );
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _removeContact(
    BuildContext context,
    String ownerId,
    String name,
  ) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove contact?'),
        content: Text(
          '$name will leave your list. The saved chat on this phone is deleted too.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: SignTalkColors.callRed,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (remove != true || !context.mounted) return;
    final scope = SignTalkScope.of(context);
    await scope.contacts.remove(ownerId: ownerId, name: name);
    await scope.conversations.clearContact(ownerId: ownerId, contactName: name);
  }

  Future<void> _renameContact(
    BuildContext context,
    String ownerId,
    String fromName,
  ) async {
    final controller = TextEditingController(text: fromName);
    final next = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename contact'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (next == null || !context.mounted) return;
    final scope = SignTalkScope.of(context);
    final error = await scope.contacts.rename(
      ownerId: ownerId,
      fromName: fromName,
      toName: next,
    );
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final saved = next.trim().replaceAll(RegExp(r'\s+'), ' ');
    await scope.conversations.renameContact(
      ownerId: ownerId,
      fromName: fromName,
      toName: saved,
    );
    await scope.activityLogs.renameContact(
      ownerId: ownerId,
      fromName: fromName,
      toName: saved,
    );
  }
}
