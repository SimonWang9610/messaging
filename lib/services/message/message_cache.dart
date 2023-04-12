import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:messaging/models/operation.dart';
import 'package:messaging/services/base/check_point.dart';
import 'package:messaging/services/chat/chat_pool.dart';
import 'package:messaging/services/message/local_database_mapping.dart';
import 'package:messaging/storage/sql_builder.dart';
import 'package:messaging/utils/utils.dart';

import '../../models/message/models.dart';
import '../../models/chat/models.dart';
import '../base/base_cache.dart';

/// when entering a chat screen by calling [subscribe], it will wait local messages loaded by [loadLocalCacheData]

class MessageCache extends BaseCache<Message, MessageEvent>
    with MessageManagerForUI, MessageDatabaseMapping {
  MessageCache({super.isBroadcast = true});

  /// key: [MessageEvent.id]
  /// temporarily holding those updates/deletions that are waiting to be committed into local database
  /// it would be consumed when [commitUpdates] is invoked
  Map<String, MessageEvent> _waitingCommit = {};

  /// temporarily holding those committed updates/deletions
  /// it would be consumed when [afterCommit] is invoked
  Map<String, MessageEvent> _committed = {};

  /// key: [Chat.docId]
  /// temporarily holding the last messages for a [Chat]
  /// it would be consumed when [afterCommit] is invoked
  Map<String, PendingLastMessage> _needsDispatchToChat = {};

  @override
  Future<void> close() async {
    _clear();

    _waitingCommit = {};
    _committed = {};
    _needsDispatchToChat = {};
    _subscriber = null;
    await super.close();
  }

  /// ensure [MessageEvent] in [_waitingCommit] is not duplicated
  /// avoid unnecessary [scheduleFlushUpdatesForUI]
  void _mergeEvent(MessageEvent event) {
    final merged = event.merge(_waitingCommit[event.id]);
    _waitingCommit[event.id] = merged;
  }

  @override
  void dispatchAll(events) {
    for (final event in events) {
      _mergeEvent(event);
    }

    scheduleCommit(debugLabel: "[MessageCache].dispatchAll");
  }

  @override
  void dispatch(event) {
    _mergeEvent(event);

    scheduleCommit(debugLabel: "[MessageCache].dispatch");
  }

  /// loop all entries in [_waitingCommit] to [writeToLocalDatabase] when [scheduleCommit] is invoked
  @override
  Future<bool> commitUpdates() async {
    bool pendingCommitted = false;

    while (_waitingCommit.isNotEmpty) {
      final waitingCommit = _waitingCommit;
      _waitingCommit = {};

      final upserts = <Message>[];
      final deletions = <Message>[];

      waitingCommit.values.forEach((event) {
        if (event.operation == Operation.deleted) {
          deletions.add(event.message);
        } else {
          upserts.add(event.message);
        }
      });

      await writeToLocalDatabase(
        "messages",
        upserts: upserts,
        deletions: deletions,
        belongTo: getCurrentUser().id,
      );

      _filterDuplicateCommittedEvents(waitingCommit.values);
      pendingCommitted = true;
    }
    return pendingCommitted;
  }

  /// once some updates/deletions are committed
  /// 1) if [_needsDispatchToChat] is not empty
  ///  notify [ChatPool] that some [Chat]'s last message have been updated
  /// 2) [storePoint] for each [Chat] in [_needsDispatchToChat]
  /// 3) if has [_subscriber], extracting those committed messages for [_subscriber]
  /// 4) finally, should notify [_subscriber] that its history and new messages are updated
  @override
  void afterCommit(bool committed) {
    final lastMessages = _needsDispatchToChat;
    _needsDispatchToChat = {};

    if (committed) {
      if (lastMessages.isNotEmpty) {
        ChatPool().cache.dispatchLastMessages(lastMessages);

        final belongTo = getCurrentUser().id;

        final points = <CheckPoint>[];
        for (final msg in lastMessages.entries) {
          points.add(
            CheckPoint(msg.key, msg.value.lastModified),
          );
        }
        saveCheckpoint(points: points, belongTo: belongTo);

        // lastMessages.forEach((key, value) {
        //   // storePoint("${Constants.chatCheckPoint}-$key",
        //   //     checkPoint: value.lastModified);
        // });
      }

      _extractMessageForSubscriber();

      scheduleFlushUpdatesForUI();
    }
  }

  @override
  void notifyCacheChange() {
    if (!eventEmitter.isClosed) {
      eventEmitter.add(
        DateTime.now().millisecondsSinceEpoch,
      );
    }
  }

  /// using [MessageEvent.finalMessage] since [Message] might be deleted
  void _filterDuplicateCommittedEvents(Iterable<MessageEvent> events) {
    for (final event in events) {
      final merged = event.merge(_committed[event.id]);
      _committed[event.id] = merged;

      final pending = _needsDispatchToChat[merged.chatId];

      if (pending != null) {
        pending.add(merged.finalMessage);
      } else {
        _needsDispatchToChat[merged.chatId] = PendingLastMessage()
          ..add(merged.finalMessage);
      }
    }
  }

  /// using [MessageEvent.finalMessage] since [Message] might be deleted
  void _extractMessageForSubscriber() {
    final committed = _committed;
    _committed = {};

    if (_subscriber == null) return;

    final messages = <Message>[];
    for (final event in committed.values) {
      if (_subscriber != null && event.chatId == _subscriber?.docId) {
        messages.add(event.finalMessage);
      }
    }

    _addMessagesForSubscriber(messages);

    _ackMessages();
  }

  void loadMoreHistoryMessages([int limit = 20]) async {
    final query = QueryBuilder(
      "messages",
      where: "belongTo = ? AND chatId = ?",
      whereArgs: [getCurrentUser().id, _subscriber!.docId],
      orderBy: "createdOn DESC",
      offset: _historyMessages.length + _messages.length,
      limit: limit,
    );

    final more = await readFromLocalDatabase(query);

    _loadMore(more);

    scheduleFlushUpdatesForUI();
  }

  void deleteLocalMessage(Message message) {
    // todo: if the message is the last message for a chat, should query the last message for the chat
    if (kIsWeb) return;

    dispatch(
      MessageEvent(
        operation: Operation.deleted,
        msgId: message.docId,
        chatId: message.chatId,
        message: message,
      ),
    );
  }
}

// todo: should ack all history messages once
mixin MessageManagerForUI on BaseCache<Message, MessageEvent> {
  Chat? _subscriber;

  void subscribe(Chat chat) {
    _subscriber = chat;
    _loadLocalCacheData().then(
      (_) {
        final lastMessage =
            _historyMessages.isNotEmpty ? _historyMessages.first : null;

        ChatPool().cache.subscribe(
              chat.copyWith(
                lastMessage: lastMessage,
                unread: 0,
              ),
            );
      },
    );
  }

  void unsubscribe() {
    if (_subscriber != null) {
      saveCheckpoint(
        points: [
          CheckPoint(
            _subscriber!.docId,
            DateTime.now().millisecondsSinceEpoch,
          )
        ],
        belongTo: getCurrentUser().id,
      );
      // storePoint(
      //   "${Constants.chatCheckPoint}-${_subscriber!.docId}",
      //   shouldFallback: true,
      // );
    }

    final lastMessage = _messages.isNotEmpty
        ? _messages.first
        : (_historyMessages.isNotEmpty ? _historyMessages.first : null);

    ChatPool().cache.unsubscribe(lastMessage);
    _subscriber = null;
    _clear();
  }

  Future<void> _loadLocalCacheData() async {
    if (_subscriber == null) return;

    final query = QueryBuilder(
      "messages",
      where: "belongTo = ? AND chatId = ?",
      whereArgs: [getCurrentUser().id, _subscriber!.docId],
      orderBy: "createdOn DESC",
      limit: 30,
      offset: 0,
    );

    final messages = await readFromLocalDatabase(query);

    _initHistoryMessages(messages);

    scheduleFlushUpdatesForUI();
  }

  /// sorted from higher to lower by [Message.createdOn]
  List<Message> _historyMessages = [];
  List<Message> get historyMessages => _historyMessages;

  /// sorted from higher to lower by [Message.createdOn]
  List<Message> _messages = [];
  List<Message> get newMessages => _messages;

  List<Message> _waitingAck = [];

  bool get hasMessage => _historyMessages.isNotEmpty || _messages.isNotEmpty;

  void _clear() {
    if (_subscriber == null) {
      _historyMessages = [];
      _messages = [];
    }
  }

  /// [messages] must be sorted
  void _initHistoryMessages(List<Message> messages) {
    _filterHistoryMessageForAck(messages);
    _historyMessages = messages;
  }

  /// [more] must be sorted descending by createdOn
  void _loadMore(List<Message> more) {
    _filterHistoryMessageForAck(more);

    _historyMessages = [...historyMessages, ...more];

    _ackMessages();
  }

  /// it is possible that we have committed some messages into the local database but not read them
  /// therefore, as long as we load history messages form local database, we should check if we should ack them
  void _filterHistoryMessageForAck(List<Message> msgs) {
    final currentUser = getCurrentUser();

    final found = msgs.where((msg) =>
        msg.status == MessageStatus.sent && msg.sender != currentUser.id);

    found.forEach((unreadMsg) => _waitingAck.add(unreadMsg));
  }

  /// [_historyMessages] indicates local messages are displayed on screen, [msg] has been committed
  /// so we just need to update messages are displaying
  /// more history messages would be loaded from local database directly
  bool _updateHistoryMsg(Message msg) {
    final index = _historyMessages
        .lastIndexWhere((item) => item.uniqueId == msg.uniqueId);

    if (index > -1) {
      if (msg.status != MessageStatus.deleted) {
        _historyMessages[index] = msg.merge(_historyMessages[index]);
      } else {
        _historyMessages.removeAt(index);
      }
      return true;
    }
    return false;
  }

  /// NOTE: all messages from [dispatchAll] should be regarded as 'new' message
  /// 1) if the msg is deleted and in [_messages], remove it from [_messages]
  /// 2) if the msg has been in [_messages], we should [Message.merge] them
  /// 3) if the msg is not in [_messages], we should insert it
  /// and try to add it into [_waitingAck] if applicable
  void _addNewMessagesForSubscriber(List<Message> messages) {
    if (messages.isEmpty) return;

    final currentUser = getCurrentUser();

    for (final msg in messages) {
      final duplicate =
          _messages.lastIndexWhere((item) => item.uniqueId == msg.uniqueId);

      if (msg.status == MessageStatus.deleted) {
        if (duplicate > -1) {
          _messages.removeAt(duplicate);
        }
      } else {
        if (duplicate > -1) {
          _messages[duplicate] = msg.merge(_messages[duplicate]);
        } else {
          _messages.add(msg);

          if (msg.sender != currentUser.id &&
              msg.status == MessageStatus.sent) {
            _waitingAck.add(msg);
          }
        }
      }
    }
    _messages.sort((a, b) => b.createdOn - a.createdOn);
  }

  /// if a [Message] is currently in [_historyMessages]
  /// we should update it to display the latest UI for this message
  /// if not in [_historyMessages], it turns out it is not on the screen (probably not loaded by [loadMoreHistoryMessages])
  /// we just ignore it since we ensure this message has been committed into the local database
  ///
  /// no [Message] would be latter than the first one in [_historyMessages]
  /// because the check point for a [Chat] would only load messages whose 'lastModified' greater than its check point
  /// as a result, we ensure the modifications for messages happen before the check-point have been committed into local database
  void _updateHistoryMessagesForSubscriber(List<Message> messages) {
    for (final msg in messages) {
      _updateHistoryMsg(msg);
    }
  }

  /// if no [_historyMessages], we treat all [messages] as 'new' messages
  /// this 'new' is relative to users' device
  void _addMessagesForSubscriber(List<Message> messages) {
    if (messages.isEmpty) return;

    if (_historyMessages.isEmpty) {
      return _addNewMessagesForSubscriber(messages);
    }

    final history = <Message>[];
    final instant = <Message>[];

    final anchor = _historyMessages.first.createdOn;

    for (final msg in messages) {
      if (msg.createdOn <= anchor) {
        history.add(msg);
      } else {
        instant.add(msg);
      }
    }

    if (history.isNotEmpty) {
      _updateHistoryMessagesForSubscriber(history);
    }

    if (instant.isNotEmpty) {
      _addNewMessagesForSubscriber(instant);
    }
  }

  void _ackMessages() {
    if (_waitingAck.isEmpty) return;
    print("need to ack: $_waitingAck");

    final submittedForAck = _waitingAck;
    _waitingAck = [];

    ChatPool().service.ackMessages(submittedForAck).then(
      (syncPoint) {
        ChatPool().cache.updateSyncPoint(syncPoint);
      },
    );
  }
}
