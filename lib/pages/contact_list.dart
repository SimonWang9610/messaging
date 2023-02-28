import 'dart:async';

import 'package:flutter/material.dart';
import 'package:messaging/models/contact/contact.dart';
import 'package:messaging/pages/message_list.dart';
import 'package:messaging/services/chat/chat_pool.dart';
import 'package:messaging/services/contact/contact_pool.dart';
import 'package:messaging/utils/utils.dart';

class ContactList extends StatefulWidget {
  const ContactList({super.key});

  @override
  State<ContactList> createState() => _ContactListState();
}

class _ContactListState extends State<ContactList>
    with AutomaticKeepAliveClientMixin {
  late final StreamSubscription<int> _sub;

  int? _lastModified;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _sub = ContactPool().cache.stream.listen(
      _handleContactChanges,
      onError: (err) {
        print("error on ContactPool: $err");
      },
    );
  }

  void _handleContactChanges(int timestamp) {
    bool shouldUpdated =
        _lastModified == null ? true : _lastModified! < timestamp;
    _lastModified = timestamp;

    if (shouldUpdated && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final contacts = ContactPool().cache.sortedContact;
    return Column(
      children: [
        Expanded(
          child: contacts.isEmpty
              ? const Text("No contacts")
              : ListView.builder(
                  itemCount: contacts.length,
                  itemBuilder: (_, index) => ContactWidget(
                    contact: contacts[index],
                  ),
                ),
        ),
      ],
    );
  }
}

class ContactWidget extends StatelessWidget {
  final Contact contact;
  const ContactWidget({
    super.key,
    required this.contact,
  });

  @override
  Widget build(BuildContext context) {
    final lastModified =
        DateTime.fromMillisecondsSinceEpoch(contact.lastModified, isUtc: false);

    return Container(
      height: 150,
      decoration: BoxDecoration(
        border: Border.all(),
        borderRadius: BorderRadius.circular(25),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
      child: ListTile(
        onTap: () async {
          final email =
              contact.inviter == ContactPool().cache.getCurrentUserEmail()
                  ? contact.invitee
                  : contact.inviter;

          context.loading(
            future: ChatPool().service.startPrivateChat(email),
            onSuccess: (chat) {
              context.push(page: MessageScreen(chat: chat));
            },
            onException: (e) {
              print("exception on creating a chat: $e");
            },
          );
        },
        title: Text(contact.id),
        trailing: Text(lastModified.toString()),
        subtitle:
            Text("inviter: ${contact.inviter}\ninvitee: ${contact.invitee}"),
      ),
    );
  }
}
