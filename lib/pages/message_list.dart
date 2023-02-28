import 'dart:async';
import 'package:flutter/material.dart';
import 'package:messaging/models/message/message_cluster.dart';
import 'package:messaging/models/message/message_status.dart';
import 'package:wrapper/wrapper.dart';

import 'package:messaging/models/chat/chat.dart';
import 'package:messaging/models/message/message.dart';
import 'package:messaging/services/message/message_pool.dart';
import '../utils/utils.dart';

class MessageScreen extends StatelessWidget {
  final Chat chat;

  const MessageScreen({super.key, required this.chat});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(chat.id),
        leading: IconButton(
          onPressed: () {
            MessagePool().unsubscribe();
            context.maybePop();
          },
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: MessageList(chat: chat),
          ),
          MessageInput(
            cluster: chat.latestCluster,
          )
        ],
      ),
    );
  }
}

class MessageList extends StatefulWidget {
  final Chat chat;
  const MessageList({
    super.key,
    required this.chat,
  });

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  late final StreamSubscription<int> _sub;

  int? _lastModified;

  @override
  void initState() {
    super.initState();

    _sub = MessagePool().subscribe(widget.chat).listen(_handleMessageChanges);
  }

  void _handleMessageChanges(int timestamp) {
    bool shouldUpdated =
        _lastModified == null ? true : _lastModified! < timestamp;
    _lastModified = timestamp;

    if (shouldUpdated && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyMessages = MessagePool().cache.historyMessages;
    final newMessages = MessagePool().cache.newMessages;

    final List<Widget> slivers = [];
    if (newMessages.isNotEmpty) {
      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            childCount: newMessages.length,
            (_, index) => MessageWidget(message: newMessages[index]),
          ),
        ),
      );
    }

    if (historyMessages.isNotEmpty) {
      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            childCount: historyMessages.length,
            (_, index) => MessageWidget(message: historyMessages[index]),
          ),
        ),
      );
    } else {
      // todo: add SliverPadding when there is no history message
    }

    return CustomScrollView(
      reverse: true,
      slivers: slivers,
    );
  }
}

class MessageWidget extends StatelessWidget {
  final Message message;
  const MessageWidget({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final sentBySelf =
        message.sender == MessagePool().cache.getCurrentUserEmail();

    final avatar = CircleAvatar(
      child: Text(message.sender[0].toUpperCase()),
    );
    const spacer = Spacer();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            sentBySelf ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          sentBySelf ? spacer : avatar,
          Flexible(
            child: _buildBody(message, sentBySelf),
          ),
          sentBySelf ? avatar : spacer,
        ],
      ),
    );
  }

  Widget _buildBody(Message msg, bool sentBySelf) {
    return Wrapper(
      spineType: sentBySelf ? SpineType.right : SpineType.left,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(msg.body),
          StatusIndicator(status: msg.status),
        ],
      ),
    );
  }
}

class StatusIndicator extends StatelessWidget {
  final MessageStatus status;
  const StatusIndicator({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    IconData? icon;
    Color? color;

    switch (status) {
      case MessageStatus.failed:
        icon = Icons.error_outline;
        color = Colors.redAccent;
        break;
      case MessageStatus.sending:
        color = Colors.grey;
        icon = Icons.pending_outlined;
        break;
      case MessageStatus.sent:
        color = Colors.white;
        icon = Icons.done_outlined;
        break;
      case MessageStatus.read:
        color = Colors.white;
        icon = Icons.done_all_outlined;
        break;
      default:
        break;
    }

    return Icon(
      icon,
      size: 12,
      color: color,
    );
  }
}

class MessageInput extends StatefulWidget {
  final String? draft;
  final MessageCluster cluster;
  const MessageInput({
    super.key,
    required this.cluster,
    this.draft,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.draft);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(30),
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
                  onPressed: enabled ? _sendMsg : null,
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

  void _sendMsg() {
    final text = _controller.text;
    _controller.clear();

    MessagePool().service.sendTextMessage(widget.cluster, text: text);
  }
}
