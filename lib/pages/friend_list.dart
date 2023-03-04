import 'dart:async';

import 'package:flutter/material.dart';
import 'package:messaging/models/friend/friend.dart';
import 'package:messaging/models/friend/friend_status.dart';
import 'package:messaging/pages/message_list.dart';
import 'package:messaging/services/chat/chat_pool.dart';
import 'package:messaging/services/friend/friend_pool.dart';
import 'package:messaging/utils/utils.dart';

class FriendList extends StatefulWidget {
  const FriendList({super.key});

  @override
  State<FriendList> createState() => _FriendListState();
}

class _FriendListState extends State<FriendList>
    with AutomaticKeepAliveClientMixin {
  late final StreamSubscription<int> _sub;

  int? _lastModified;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _sub = FriendPool().cache.stream.listen(
      _handleFriendChanges,
      onError: (err) {
        print("error on FriendPool: $err");
      },
    );
  }

  void _handleFriendChanges(int timestamp) {
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
    final friends = FriendPool().cache.friends;
    return Column(
      children: [
        Expanded(
          child: friends.isEmpty
              ? const Text("No Friends")
              : ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (_, index) => FriendWidget(
                    friend: friends[index],
                  ),
                ),
        ),
      ],
    );
  }
}

class FriendWidget extends StatelessWidget {
  final Friend friend;
  const FriendWidget({
    super.key,
    required this.friend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        border: Border.all(),
        borderRadius: BorderRadius.circular(25),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          CircleAvatar(
            child: Text(
              friend.username[0].toUpperCase(),
            ),
          ),
          Expanded(
            child: ListTile(
              title: Text(friend.nickname ?? friend.username),
              onTap: friend.status == FriendStatus.accepted
                  ? () => _startChat(context)
                  : null,
              trailing: friend.status == FriendStatus.pending
                  ? _buildTailing(context, friend)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  void _startChat(BuildContext context) {
    context.loading(
      future: ChatPool().service.startPrivateChat(friend.userId),
      onSuccess: (chat) {
        context.push(page: MessageScreen(chat: chat));
      },
      onException: (e) {
        print("exception on creating a chat: $e");
      },
    );
  }

  Widget _buildTailing(BuildContext context, Friend friend) {
    final currentUser = FriendPool().cache.getCurrentUser();
    final createdBySelf = currentUser.id == friend.createdBy;

    return OutlinedButton(
      onPressed: !createdBySelf ? () => _accept(context, friend) : null,
      child: createdBySelf ? const Text("Pending") : const Text("Accept"),
    );
  }

  void _accept(BuildContext context, Friend friend) {
    context.loading(
      future: FriendPool().service.accept(friend),
      onException: (e) {
        print("exception on accepting invitation: $e");
      },
    );
  }
}

class AddFriend extends StatefulWidget {
  const AddFriend({super.key});

  @override
  State<AddFriend> createState() => _AddFriendState();
}

class _AddFriendState extends State<AddFriend> {
  final TextEditingController _controller =
      TextEditingController(text: "dengpan1002.wang@gmail.com");

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      width: 500,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        child: TextField(
          controller: _controller,
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
            border: const OutlineInputBorder(),
            suffixIcon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (_, value, __) {
                final enabled = value.text.isNotEmpty;

                return OutlinedButton(
                  onPressed: enabled ? _addFriend : null,
                  child: Icon(
                    Icons.send_outlined,
                    color: enabled ? Colors.blueAccent : Colors.grey,
                  ),
                );
              },
              // child: const Icon(Icons.send_outlined),
            ),
          ),
        ),
      ),
    );
  }

  void _addFriend() async {
    context.loading(
      future: FriendPool().service.searchUser(_controller.text),
      onSuccess: (user) {
        if (user != null) {
          FriendPool().service.addFriend(user);
        } else {
          print("no user found for ${_controller.text}");
        }
        context.hideDialog();
      },
      onException: (e) {
        print(e);
      },
    );
  }
}
