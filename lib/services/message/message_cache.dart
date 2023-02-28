import 'dart:async';
import 'dart:math';

import 'package:flutter/scheduler.dart';
import 'package:messaging/services/chat/chat_pool.dart';
import 'package:messaging/utils/utils.dart';

import '../../models/message/models.dart';
import '../../models/chat/models.dart';
import '../base/base_cache.dart';

// todo: send ack for loaded/read messages
// todo: handle messages arrive before its chat
// todo: update the last messages for chats

/// when [dispatch]/[dispatchAll] events
/// 1) we should first [_mergeEvent] synchronously to avoid updating the same [Message] duplicate in a short time
///
/// 2) then we need to [_flushPendingEvents] to write those unique pending events into the local database asynchronously
///until [_waitingCommit] is empty. Therefore, during [_flushPendingEvents],
/// it may have other events that are added by other [dispatch]/[dispatchAll] are [_addCommittedEvents]
///
/// 3) we start [_extractMessageForSubscriber] from [_committed],
/// since we just want to display [Message]s that have been synced in the local database.
///
/// 4) finally, we [scheduleFlushMessages] to [_subscriber] after delaying [duration].
/// it would invoke [_flushMessageForSubscriber] at the end of frame.
///
/// entering a chat screen should invoke [subscribe] to listen to history/updated [Message]s
/// by invoking [subscribe], [loadLocalCacheData] would also execute asynchronously
class MessageCache extends BaseCache<int, MessageEvent>
    with MessageManagerForUI {
  MessageCache({super.isBroadcast = true});

  Map<String, MessageEvent> _waitingCommit = {};
  Map<String, MessageEvent> _committed = {};
  Map<String, PendingLastMessage> _needsDispatchToChat = {};

  Duration duration = const Duration(milliseconds: 60);

  @override
  Future<void> close() async {
    _clear();

    _waitingCommit.clear();
    _subscriber = null;
    await super.close();
  }

  /// ensure [MessageEvent] in [_waitingCommit] are unique
  /// avoid unnecessary flushing
  void _mergeEvent(MessageEvent event) {
    final merged = event.merge(_waitingCommit[event.id]);
    _waitingCommit[event.id] = merged;
  }

  @override
  void dispatchAll(events) {
    for (final event in events) {
      _mergeEvent(event);
    }

    scheduleCommit(
      _commitPendingEvents,
      afterCommitted: _afterCommit,
      debugLabel: "[MessageCache].dispatchAll",
    );
  }

  @override
  void dispatch(event) {
    _mergeEvent(event);

    scheduleCommit(
      _commitPendingEvents,
      afterCommitted: _afterCommit,
      debugLabel: "[MessageCache].dispatch",
    );
  }

  void _afterCommit(bool committed) {
    final lastMessages = _needsDispatchToChat;
    _needsDispatchToChat = {};

    if (committed) {
      if (lastMessages.isNotEmpty) {
        ChatPool().cache.dispatchLastMessages(lastMessages);
      }

      _extractMessageForSubscriber();
      scheduleFlushMessages();
    }
  }

  Future<bool> _commitPendingEvents() async {
    bool pendingCommitted = false;

    while (_waitingCommit.isNotEmpty) {
      final waitingCommit = _waitingCommit;
      _waitingCommit = {};

      // todo: commit events to local database
      await Future.delayed(duration, () {
        print("[MessageCache]: write to local database");
      });

      _filterDuplicateCommittedEvents(waitingCommit.values);
      pendingCommitted = true;
    }
    return pendingCommitted;
  }

  void _filterDuplicateCommittedEvents(Iterable<MessageEvent> events) {
    for (final event in events) {
      final merged = event.merge(_committed[event.id]);
      _committed[event.id] = merged;

      final pending = _needsDispatchToChat[merged.chatId];

      if (pending != null) {
        pending.add(merged.message);
      } else {
        _needsDispatchToChat[merged.chatId] = PendingLastMessage()
          ..add(merged.message);
      }
    }
  }

  void _extractMessageForSubscriber() {
    final committed = _committed;
    _committed = {};

    final chats = <String, int>{};

    final messages = <Message>[];
    for (final event in committed.values) {
      if (chats.containsKey(event.chatId)) {
        chats[event.chatId] =
            max(chats[event.chatId]!, event.message.lastModified);
      } else {
        chats[event.chatId] = event.message.lastModified;
      }
      if (_subscriber != null && event.chatId == _subscriber?.id) {
        messages.add(event.message);
      }
    }

    chats.forEach(
      (key, value) {
        CheckPointManager.store("${Constants.chatCheckPoint}-$key",
            checkPoint: value);
      },
    );

    _addMessagesForSubscriber(messages);
  }

  void scheduleFlushMessages() {
    if (!hasMessage || _subscriber == null) {
      return;
    }

    SchedulerBinding.instance.endOfFrame.then(
      (_) {
        _ackMessages();

        if (!eventEmitter.isClosed) {
          eventEmitter.add(
            DateTime.now().millisecondsSinceEpoch,
          );
        }
      },
    );
  }

  /// when a chat screen is displayed, [subscribe] would invoke [loadLocalCacheData] to load [CachedType.history] messages
  ///
  @override
  Future<void> loadLocalCacheData() async {
    if (_subscriber == null) return;

    // todo: should load messages from local database
    final historyMessages =
        ChatPool().cache.getPendingMessages(_subscriber!.id);

    _initHistoryMessages(historyMessages ?? []);

    if (!eventEmitter.isClosed) {
      eventEmitter.add(
        DateTime.now().millisecondsSinceEpoch,
      );
    }
  }

  void loadMoreHistoryMessages([int limit = 20]) async {
    await Future.delayed(duration, () {
      print("querying more history messages");
    });

    _loadMore([]);

    if (!eventEmitter.isClosed) {
      eventEmitter.add(
        DateTime.now().millisecondsSinceEpoch,
      );
    }
  }
}

// todo: should ack all history messages once
mixin MessageManagerForUI on BaseCache<int, MessageEvent> {
  Chat? _subscriber;

  void subscribe(Chat chat) {
    _subscriber = chat;
    ChatPool().cache.subscribed = chat;
    loadLocalCacheData();
    // todo: ack messages read
    // todo: clear unread count
  }

  void unsubscribe() {
    if (_subscriber != null) {
      CheckPointManager.store(
        "${Constants.chatCheckPoint}-${_subscriber!.id}",
        shouldFallback: true,
      );
    }
    _subscriber = null;
    _clear();
    ChatPool().cache.subscribed = null;
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
    _historyMessages = [];
    _messages = [];
  }

  /// [messages] must be sorted
  void _initHistoryMessages(List<Message> messages) {
    _ackHistoryMessages(messages);
    _historyMessages = messages;
  }

  /// [more] must be sorted
  void _loadMore(List<Message> more) {
    _ackHistoryMessages(more);

    _historyMessages = [...historyMessages, ...more];
  }

  /// it is possible that we have committed some messages into the local database but not read them
  /// therefore, as long as we load history messages form local database, we should check if we should ack them
  void _ackHistoryMessages(List<Message> msgs) {
    final found = msgs.where((msg) =>
        msg.status == MessageStatus.sent &&
        msg.sender != getCurrentUserEmail());

    found.forEach((unreadMsg) => _waitingAck.add(unreadMsg));

    _ackMessages();
  }

  /// [_historyMessages] indicates those messages are displayed on screen, [msg] has been committed
  /// so we just need to update those messages are displaying
  /// more history messages would be loaded from local database directly
  bool _updateHistoryMsg(Message msg) {
    final index = _historyMessages
        .lastIndexWhere((item) => item.uniqueId == msg.uniqueId);

    if (index > -1) {
      _historyMessages[index] = msg.merge(_historyMessages[index]);
      return true;
    }
    return false;
  }

  /// NOTE: all messages from [dispatchAll] should be regarded as 'new' message
  /// 1) if the msg is deleted and in [_messages], remote it from [_messages]
  /// 2) if the msg has been in [_messages], we should [Message.merge] them
  /// 3) if the msg is not in [_messages], we should insert it
  /// and try to add it into [_waitingAck] if applicable
  void _addNewMessagesForSubscriber(List<Message> messages) {
    if (messages.isEmpty) return;

    for (final msg in messages) {
      final duplicate =
          _messages.lastIndexWhere((item) => item.uniqueId == msg.uniqueId);

      if (duplicate > -1 && msg.status == MessageStatus.deleted) {
        _messages.removeAt(duplicate);
      } else {
        if (duplicate > -1) {
          _messages[duplicate] = msg.merge(_messages[duplicate]);
        } else {
          _messages.add(msg);

          if (msg.sender != getCurrentUserEmail() &&
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
  /// if not in [_historyMessages], it turns out it is not on the screen
  /// we just ignore it since we ensure this message has been committed into the local database
  /// no [Message] would be latter than the last one in [_historyMessages]
  /// because the check point for a [Chat] would restrict only to load messages whose 'lastModified' greater than its check point
  /// as a result, we ensure the modifications for messages happen before the check-point have been committed into local database
  void _updateHistoryMessagesForSubscriber(List<Message> messages) {
    for (final msg in messages) {
      _updateHistoryMsg(msg);
    }
  }

  /// if no [_historyMessages], we treat all [messages] as new messages
  void _addMessagesForSubscriber(List<Message> messages) {
    if (messages.isEmpty) return;

    if (_historyMessages.isEmpty) {
      return _addNewMessagesForSubscriber(messages);
    }

    final history = <Message>[];
    final instant = <Message>[];

    final anchor = _historyMessages.first.createdOn;

    for (final msg in messages) {
      if (msg.createdOn < anchor) {
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
