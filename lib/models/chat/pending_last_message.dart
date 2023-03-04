import 'dart:math';

import 'package:messaging/models/message/models.dart';

import 'sync_point.dart';

/// designed for the chat that has not ready to update itself
/// e.g., the remote chats have not been loaded but their messages are loaded
/// before a chat is committed into the local database
/// it should consume its [PendingLastMessage]
class PendingLastMessage {
  int? _lastModified;

  Message? _lastMessage;

  /// [_messages] no need to be sorted
  final List<Message> _messages;

  PendingLastMessage({List<Message>? messages}) : _messages = messages ?? [];

  List<Message> get messages => _messages;

  /// before invoking [countUnread], we should ensure [_lastMessage]'s status is not [MessageStatus.deleted]
  void add(Message lastMessage) {
    if (lastMessage.status != MessageStatus.deleted) {
      _lastMessage = lastMessage.compareCreatedOn(_lastMessage);
    }

    if (_lastModified == null) {
      _lastModified = lastMessage.lastModified;
    } else {
      _lastModified = max(_lastModified!, lastMessage.lastModified);
    }

    final duplicate =
        _messages.lastIndexWhere((msg) => msg.uniqueId == lastMessage.uniqueId);

    if (duplicate > -1) {
      _messages[duplicate] = _messages[duplicate].merge(lastMessage);
    } else {
      _messages.add(lastMessage);
    }
  }

  /// [add] ensure [_messages] has no duplicate message
  /// so we could assert there is at most one duplicate in [pending] compared to [_messages]
  void merge(PendingLastMessage pending) {
    final mergedMessages = <Message>[];

    _lastMessage = _lastMessage != null
        ? _lastMessage!.compareCreatedOn(pending.last)
        : pending.last?.compareCreatedOn(_lastMessage);

    _lastModified = max(_lastModified!, pending.lastModified);

    for (final old in _messages) {
      final duplicate = pending.messages
          .lastIndexWhere((msg) => msg.uniqueId == old.uniqueId);

      if (duplicate > -1) {
        final msg = old.merge(pending.messages.removeAt(duplicate));
        mergedMessages.add(msg);
      } else {
        mergedMessages.add(old);
      }
    }

    _messages.clear();
    _messages.addAll([...mergedMessages, ...pending.messages]);
  }

  // todo: count if some unread messages are deleted/rollback
  /// 1) if the chat is currently subscribed (chatting)
  /// no need to count unread, just update its last message for the chat list
  ///
  /// 2) if the chat's [syncPoint] is not ready
  /// counting unread if the message is sent by others and later than [previous]
  ///
  /// otherwise, we count unread only when the below conditions are fulfilled;
  /// i. [syncPoint] could be applied to the message
  /// ii. created later than the [syncPoint]
  /// iii. not sent by the current user
  /// iv. later than [previous] since the message might have been counted
  ///
  /// [previous] indicates the previous last message of the chat
  ///
  /// if the pending messages contains some deleted messages, we should care decreasing the unread count
  ///
  /// 1) if this message should be counting but deleted after counting, we should decrement unread count
  /// by comparing the message with [previous], we could know if it has been counted
  ///
  /// 2) if the latter message between [_lastMessage] and [previous] is identical to [lastDeleted]
  /// if [previous] is notified deleted (identical to [lastDeleted])
  /// we should compare the latter message between [_lastMessage] and [previous]
  /// so as to determine if displaying 'DELETED MESSAGE'
  ///
  int countUnread(
    String currentUser, {
    SyncPoint? syncPoint,
    Message? previous,
    bool isSubscribed = false,
  }) {
    if (isSubscribed || _messages.isEmpty) {
      return 0;
    } else if (syncPoint == null) {
      return _messages.where(
        (msg) {
          final sentByOther = msg.sender != currentUser;
          final laterThanPrevious =
              previous == null || msg.createdOn > previous.createdOn;
          final unreadStatus = msg.status == MessageStatus.sent;
          return sentByOther && laterThanPrevious && unreadStatus;
        },
      ).length;
    }

    int count = 0;

    Message? lastDeleted;

    for (final msg in _messages) {
      final shouldCounting = msg.chatId == syncPoint.chatId &&
          msg.createdOn > syncPoint.lastSync &&
          msg.sender != currentUser;

      if (shouldCounting) {
        if (msg.status == MessageStatus.deleted) {
          if (previous != null && msg.createdOn <= previous.createdOn) {
            count--;
          }
        } else if (previous == null || (msg.createdOn > previous.createdOn)) {
          // since the sync point would be updated once some messages are read/updated
          // so we could safely increment count
          count++;
        }
      }

      if (msg.status == MessageStatus.deleted) {
        lastDeleted = msg.compareCreatedOn(lastDeleted);
      }
    }
    _lastMessage = _lastMessage?.compareCreatedOn(previous) ??
        previous?.compareCreatedOn(_lastMessage);

    if (lastDeleted != null && previous?.uniqueId == lastDeleted.uniqueId) {
      if (_lastMessage?.uniqueId == lastDeleted.uniqueId) {
        _lastMessage = lastDeleted.copyWith(body: "[Deleted Message]");
      }
    }

    return count;
  }

  Message? get last => _lastMessage;

  int get lastModified => _lastModified!;
}
