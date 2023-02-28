import 'package:flutter/scheduler.dart';

import 'package:messaging/models/chat/sync_point.dart';
import 'package:messaging/models/message/models.dart';
import 'package:messaging/models/operation.dart';
import 'package:messaging/utils/utils.dart';

import '../../models/chat/models.dart';
import '../base/base_cache.dart';
import '../message/message_pool.dart';

// todo: handle [loadLocalCacheData]
// todo: handle message deletion for the chat list
class ChatCache extends BaseCache<int, ChatEvent> {
  ChatCache({super.isBroadcast = false});

  final Map<String, Chat> _localChats = {};
  final Map<String, SyncPoint> _syncPoints = {};
  final Map<String, PendingLastMessage> _pendingLastMessages = {};

  Map<String, Chat> _waitingCommit = {};

  List<MessageCluster> get clusters =>
      _localChats.values.map((e) => e.latestCluster).toList();

  List<Chat> get sortedChat => _localChats.values.toList()
    ..sort((a, b) => a.lastModified - b.lastModified);

  int? _latterLastModified;

  // todo: only for testing, should remove once SQLite has been enabled
  List<Message>? getPendingMessages(String chatId) {
    final pending = _pendingLastMessages[chatId];
    if (pending != null) {
      return pending.messages..sort((a, b) => a.createdOn - b.createdOn);
    }
    return null;
  }

  @override
  Future<void> init() async {
    await loadLocalCacheData();
    _latterLastModified = CheckPointManager.get(Constants.chatCheckPoint);
  }

  @override
  Future<void> loadLocalCacheData() async {
    // todo: init _localChats
  }

  @override
  void dispatch(event) {
    final merged = event.chat.merge(_localChats[event.chatId]);
    if (event.operation == Operation.added) {
      MessagePool().service.addCluster(merged.latestCluster);
    }
    _syncLocalChat(merged);

    scheduleCommit(
      _commitChatUpdates,
      afterCommitted: (committed) {
        if (committed) scheduleFlushChatUpdates();
      },
      debugLabel: "[ChatCache].dispatch",
    );
  }

  /// for old device, [dispatchAll] typically is invoked when a [Chat] is added or the [Chat.members] is changed
  /// for a new device, [dispatchAll] is also invoked when loading all history [Chat]s
  @override
  void dispatchAll(events) {
    for (final event in events) {
      final merged = event.chat.merge(_localChats[event.chatId]);

      if (event.operation == Operation.added) {
        MessagePool().service.addCluster(merged.latestCluster);
      }

      _syncLocalChat(merged);
    }
    // todo: should flush updates into local database

    scheduleCommit(
      _commitChatUpdates,
      afterCommitted: (committed) {
        if (committed) scheduleFlushChatUpdates();
      },
      debugLabel: "[ChatCache].dispatchAll",
    );
  }

  /// when [dispatchLastMessages], a [Chat] mat not be ready in [_localChats]
  /// so we should add such messages in [_pendingLastMessages]
  /// so that [Chat]s could be synced when [dispatch]/[dispatchAll] is triggered
  ///
  /// if a [Chat] is subscribed, [PendingLastMessage.countUnread] would always return 0
  void dispatchLastMessages(Map<String, PendingLastMessage> lastMessages) {
    for (final entry in lastMessages.entries) {
      _addPendingMessage(entry.key, entry.value);

      _syncLocalChat(_localChats[entry.key]);
    }

    scheduleCommit(
      _commitChatUpdates,
      afterCommitted: (committed) {
        if (committed) scheduleFlushChatUpdates();
      },
      debugLabel: "dispatchLastMessages",
    );
  }

  Chat? _subscribed;

  // todo: do we need to force sync chat when starting a chat?
  /// when starting chat for [chat], we need to reset its unread to 0
  /// therefore, we need to [scheduleCommit] to update its unread so as to update the chat list UI
  /// when leaving a chat, we do not need to anything special
  /// because its unread count would not change, and its lat last message would be updated together with other chats
  set subscribed(Chat? chat) {
    if (_subscribed == chat) return;

    _subscribed = chat?.copyWith(unread: 0);
    _syncLocalChat(_subscribed);

    // if (_subscribed != null) {
    //   scheduleCommit(
    //     _commitChatUpdates,
    //     afterCommitted: (committed) {
    //       if (committed) scheduleFlushChatUpdates();
    //     },
    //     debugLabel: "subscribed",
    //   );
    // }
  }

  /// by using while-loop, we could merge events from [dispatch]/[dispatchAll] into one commit operation
  /// when invoke [scheduleCommit], [hasCommitScheduled] could avoid invoking [_commitChatUpdates] multiple times in a very short time
  /// as a result, we only need to invoke [scheduleFlushChatUpdates] once for multiple [dispatch]/[dispatchAll]
  Future<bool> _commitChatUpdates() async {
    bool updatesCommitted = false;

    while (_waitingCommit.isNotEmpty) {
      final chats = _waitingCommit;
      _waitingCommit = {};

      await _writeToLocalDatabase(chats.values.toList());

      for (final chatId in chats.keys) {
        _localChats[chatId] = chats[chatId]!;
      }
      updatesCommitted = true;
    }
    return updatesCommitted;
  }

  Future<void> _writeToLocalDatabase(List<Chat> chats) async {
    await Future.delayed(const Duration(milliseconds: 120), () {
      print("[ChatCache]: write to local database");
    });
  }

  /// typically, it happens when the [chatId] is not ready in [_localChats]
  /// so we have to accumulate its messages until it is synced using [_syncLocalChat]
  void _addPendingMessage(String chatId, PendingLastMessage pending) {
    final oldPending = _pendingLastMessages[chatId];
    if (oldPending != null) {
      print("merge pending");
      oldPending.merge(pending);
    } else {
      print("add pending");
      _pendingLastMessages[chatId] = pending;
    }
  }

  /// 1) use the latest [SyncPoint]
  /// 2) check the [PendingLastMessage] for [chat]
  /// 3) count unread
  ///   i. if [Chat.syncPoint] is null, we treat all pending messages are unread. Typically, this case happens when this [chat] is new
  ///   ii. if [chat] is subscribed, unread would be 0
  ///   iii. otherwise, we use its [SyncPoint] to compare each pending message
  /// 4) sync [chat], if there are some changes happen to [chat] or the synced [Chat] is not loaded in [_localChats]
  /// we should commit its updates into the local database
  /// if no changes or not [forceSync], we just replace [chat] with the synced chat
  void _syncLocalChat(Chat? chat, {bool forceSync = false}) {
    if (chat == null) return;

    final syncPoint =
        chat.syncPoint?.compare(_syncPoints[chat.id]) ?? _syncPoints[chat.id];

    final pending = _pendingLastMessages.remove(chat.id);

    final unread = pending?.countUnread(
          getCurrentUserEmail(),
          syncPoint: syncPoint,
          isSubscribed: chat.id == _subscribed?.id,
        ) ??
        0;

    final syncedChat = chat.copyWith(
      syncPoint: syncPoint,
      lastMessage: pending?.last,
      unread: chat.unread + unread,
    );

    if (syncedChat != chat ||
        !_localChats.containsKey(syncedChat.id) ||
        forceSync) {
      _waitingCommit[syncedChat.id] = syncedChat;
    } else {
      _localChats[syncedChat.id] = syncedChat;
    }
  }

  /// during [updateSyncPoints], some [Chat] mat not be ready at [_localChats]
  /// so we just ignore those not-ready chats since we guarantee then would be synced in [dispatch]/[dispatchAll]
  /// if the [Chat] has been ready, we should [_syncLocalChat]
  Future<void> updateSyncPoints(List<Map<String, dynamic>> syncPoints) async {
    syncPoints.forEach((map) {
      final syncPoint = SyncPoint.fromMap(map);
      _syncPoints[syncPoint.chatId] = syncPoint;
      _syncLocalChat(_localChats[syncPoint.chatId]);
    });

    scheduleCommit(
      _commitChatUpdates,
      afterCommitted: (committed) {
        if (committed) scheduleFlushChatUpdates();
      },
      debugLabel: "updateSyncPoints",
    );
  }

  // todo: should store check point
  void updateSyncPoint(SyncPoint syncPoint) {
    _syncPoints[syncPoint.chatId] =
        syncPoint.compare(_syncPoints[syncPoint.chatId]);

    _syncLocalChat(_localChats[syncPoint.chatId]);

    if (_subscribed != null && _subscribed!.id == syncPoint.chatId) {
      _subscribed = _localChats[_subscribed!.id];
    }

    scheduleCommit(
      _commitChatUpdates,
      afterCommitted: (committed) {
        if (committed) scheduleFlushChatUpdates();
      },
      debugLabel: "updateSyncPoint",
    );
  }

  void scheduleFlushChatUpdates([int? timestamp]) {
    _latterLastModified = DateTime.now().millisecondsSinceEpoch;

    SchedulerBinding.instance.endOfFrame.then(
      (_) async {
        await CheckPointManager.store(
          Constants.chatCheckPoint,
          checkPoint: timestamp ?? _latterLastModified,
        );
        _latterLastModified = CheckPointManager.get(Constants.chatCheckPoint)!;

        if (!eventEmitter.isClosed) {
          eventEmitter.add(_latterLastModified!);
        }
      },
    );
  }

  Chat? findChatByHash(String hash) {
    final found = _localChats.values.where((chat) => chat.membersHash == hash);
    if (found.isNotEmpty) {
      return found.first;
    }
    return null;
  }

  @override
  Future<void> close() async {
    _localChats.clear();
    await super.close();
  }
}
