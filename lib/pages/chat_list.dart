import 'dart:async';

import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;
import 'package:messaging/models/chat/chat.dart';
import 'package:messaging/pages/message_list.dart';
import 'package:messaging/services/chat/chat_pool.dart';
import '../utils/utils.dart';

class ChatList extends StatefulWidget {
  const ChatList({super.key});

  @override
  State<ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<ChatList>
    with AutomaticKeepAliveClientMixin {
  late final StreamSubscription<int> _sub;

  int? _lastModified;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _sub = ChatPool().cache.stream.listen(_handleChatChanges);
  }

  void _handleChatChanges(int timestamp) {
    bool shouldUpdated =
        _lastModified == null ? true : _lastModified! < timestamp;
    _lastModified = timestamp;
    print("should update: $shouldUpdated");

    if (shouldUpdated && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final chats = ChatPool().cache.sortedChat;

    return Column(
      children: [
        Expanded(
          child: chats.isEmpty
              ? const Text("No chats")
              : ListView.builder(
                  itemCount: chats.length,
                  itemBuilder: (_, index) => ChatWidget(
                    chat: chats[index],
                  ),
                ),
        ),
      ],
    );
  }
}

class ChatWidget extends StatelessWidget {
  final Chat chat;
  const ChatWidget({
    super.key,
    required this.chat,
  });

  @override
  Widget build(BuildContext context) {
    print("CHAT: $chat");
    final lastModified =
        DateTime.fromMillisecondsSinceEpoch(chat.lastModified, isUtc: false);

    final title = ChatPool().findChatName(chat);

    return Container(
      height: 120,
      decoration: BoxDecoration(
        border: Border.all(),
        borderRadius: BorderRadius.circular(25),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          badges.Badge(
            badgeStyle: const badges.BadgeStyle(),
            showBadge: chat.unread > 0,
            badgeContent: Text("${chat.unread}"),
            child: CircleAvatar(
              child: Text(
                title?[0].toUpperCase() ?? chat.docId[0].toUpperCase(),
              ),
            ),
          ),
          Expanded(
            child: ListTile(
              onTap: () {
                context.push(
                  page: MessageScreen(chat: chat),
                );
              },
              title: Text(title ?? chat.docId),
              trailing: Text(lastModified.toString()),
              subtitle: Text(chat.lastMessage?.body ?? "[No message]"),
            ),
          ),
        ],
      ),
    );
  }
}
