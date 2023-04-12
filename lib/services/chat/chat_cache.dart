import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:messaging/models/message/models.dart';
import 'package:messaging/models/operation.dart';
import 'package:messaging/services/base/check_point.dart';
import 'package:messaging/services/chat/local_database_mapping.dart';
import 'package:messaging/storage/sql_builder.dart';
import 'package:messaging/utils/utils.dart';

import '../../models/chat/models.dart';
import '../base/base_cache.dart';
import '../message/message_pool.dart';

// todo: handle chat reloading if users deleted a chat from the chat list (not physically deleted)

class ChatCache extends BaseCache<Chat, ChatEvent> with ChatDatabaseMapping {
  ChatCache({super.isBroadcast = false});

  // todo: make it temporarily
  /// key: [Chat.docId]
  final Map<String, SyncPoint> _syncPoints = {};

  /// key: [Chat.docId]/[ChatEvent.chatId], they are equivalent
  /// temporarily holding [PendingLastMessage] for chats that are not ready in local database
  /// although such cases are rarely
  /// we use this as a formal process to reduce the complexity between [MessagePool] and [ChatPool]
  final Map<String, PendingLastMessage> _pendingLastMessages = {};

  /// the local chat loaded in the memory
  final Map<String, Chat> _localChats = {};

  Map<String, Chat> _waitingCommit = {};

  List<MessageCluster> get clusters =>
      _localChats.values.map((e) => e.latestCluster).toList();

  List<Chat> get sortedChat => _localChats.values.toList()
    ..sort((a, b) {
      if (a.lastMessage == null || b.lastMessage == null) {
        return a.lastMessage?.lastModified ??
            b.lastMessage?.lastModified ??
            a.lastModified - b.lastModified;
      } else {
        return a.lastMessage!.lastModified - b.lastMessage!.lastModified;
      }
    });

  int? _latterLastModified;

  @override
  Future<void> init() async {
    final currentUser = getCurrentUser();
    final query = QueryBuilder(
      "chats",
      where: "belongTo = ?",
      whereArgs: [currentUser.id],
    );
    final chats = await readFromLocalDatabase(query);

    chats.forEach((chat) {
      _localChats[chat.docId] = chat;
    });

    _latterLastModified =
        await getCheckPoint(Constants.chatCheckPoint, currentUser.id);
  }

  /// for all changes dispatched by [dispatch]/[dispatchAll]
  /// they would be processed by [_syncLocalChat] to filter some of them that require being committed
  /// prior to [scheduleCommit]
  @override
  void dispatch(event) {
    final merged = event.chat.merge(_localChats[event.chatId]);
    if (event.operation == Operation.added) {
      MessagePool().service.addCluster(merged.latestCluster);
    }
    _syncLocalChat(merged);

    scheduleCommit(debugLabel: "[ChatCache].dispatch");
  }

  /// for old device, [dispatchAll] typically is invoked when a [Chat] is added or the [Chat.members] is changed
  /// for a new device, [dispatchAll] is also invoked when loading all history [Chat]s compared to its local check point
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

    scheduleCommit(debugLabel: "[ChatCache].dispatchAll");
  }

  @override
  Future<bool> commitUpdates() async {
    bool updatesCommitted = false;

    while (_waitingCommit.isNotEmpty) {
      final chats = _waitingCommit;
      _waitingCommit = {};

      await writeToLocalDatabase(
        "chats",
        upserts: chats.values.toList(),
        belongTo: getCurrentUser().id,
      );

      for (final chatId in chats.keys) {
        _localChats[chatId] = chats[chatId]!;

        if (_latterLastModified == null) {
          _latterLastModified = chats[chatId]!.lastModified;
        } else {
          _latterLastModified =
              max(_latterLastModified!, chats[chatId]!.lastModified);
        }
      }
      updatesCommitted = true;
    }
    return updatesCommitted;
  }

  @override
  void afterCommit(committed) {
    if (committed) {
      // storePoint(
      //   Constants.chatCheckPoint,
      //   checkPoint: _latterLastModified,
      // );

      saveCheckpoint(
        points: [CheckPoint(Constants.chatCheckPoint, _latterLastModified!)],
        belongTo: getCurrentUser().id,
      );

      scheduleFlushUpdatesForUI();
    }
  }

  @override
  void notifyCacheChange() async {
    if (!eventEmitter.isClosed && _latterLastModified != null) {
      eventEmitter.add(DateTime.now().millisecondsSinceEpoch);
    }
  }

  // todo: a chat is removed from [_loadChats], should reload it if its new messages are dispatched
  /// e.g., the user removes a chat from the chat list, but we should not delete this chat from firestore
  /// we just need to remove it from [_localChats] and do nothing on the local database and firestore
  /// when its new messages are dispatched, we should try reloading it from the local database
  ///
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

    scheduleCommit(debugLabel: "dispatchLastMessages");
  }

  /// happens after completing [ChatPool.service.ackMessages] that are invoked when marking messages as read
  void updateSyncPoint(SyncPoint syncPoint) {
    _syncPoints[syncPoint.chatId] =
        syncPoint.compare(_syncPoints[syncPoint.chatId]);

    _syncLocalChat(_localChats[syncPoint.chatId]);

    if (_subscribed != null && _subscribed!.docId == syncPoint.chatId) {
      _subscribed = _localChats[_subscribed!.docId];
    }

    scheduleCommit(debugLabel: "updateSyncPoint");
  }

  /// during [updateSyncPoints], some [Chat] mat not be ready at [_localChats]
  /// so we just ignore those not-ready chats since we guarantee they would be synced in [dispatch]/[dispatchAll]
  /// if the [Chat] has been ready, we should [_syncLocalChat] directly
  Future<void> updateSyncPoints(List<Map<String, dynamic>> syncPoints) async {
    syncPoints.forEach((map) {
      final syncPoint = SyncPoint.fromMap(map);
      _syncPoints[syncPoint.chatId] = syncPoint;
      _syncLocalChat(_localChats[syncPoint.chatId]);
    });

    scheduleCommit(debugLabel: "updateSyncPoints");
  }

  Chat? _subscribed;

  void subscribe(Chat chat) {
    if (_subscribed == chat) return;
    _subscribed = chat;
    _syncLocalChat(_subscribed);
    scheduleCommit(debugLabel: "[ChatCache].subscribe]");
  }

  void unsubscribe(Message? lastMessage) {
    if (_subscribed == null) return;

    _syncLocalChat(_subscribed?.copyWith(lastMessage: lastMessage));
    _subscribed = null;
    scheduleCommit(debugLabel: "[ChatCache].unsubscribe]");
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

  /// todo: avoid adding the same [Chat] into [_waitingCommit]
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

    final syncPoint = chat.syncPoint?.compare(_syncPoints[chat.docId]) ??
        _syncPoints[chat.docId];

    final pending = _pendingLastMessages.remove(chat.docId);

    final unread = pending?.countUnread(
          getCurrentUser().id,
          syncPoint: syncPoint,
          isSubscribed: chat.docId == _subscribed?.docId,
          previous: chat.lastMessage,
        ) ??
        0;

    final syncedChat = chat.copyWith(
      syncPoint: syncPoint,
      lastMessage: pending?.last,
      unread: chat.unread + unread,
    );

    if (syncedChat != _localChats[syncedChat.docId] || forceSync) {
      _waitingCommit[syncedChat.docId] = syncedChat;
    }
  }

  Chat? findChatByHash(String hash) {
    final found = _localChats.values.where((chat) => chat.membersHash == hash);
    if (found.isNotEmpty) {
      return found.first;
    }
    return null;
  }

  Chat? findChatById(String chatId) {
    return _localChats[chatId];
  }

  @override
  Future<void> close() async {
    _localChats.clear();
    await super.close();
  }
}

// todo: not using
// mixin CacheReloading on BaseCache<Chat, ChatEvent>, ChatDatabaseMapping {
//   Map<String, Chat> get _localChats;

//   Map<String, Chat?> _needsReloading = {};

//   Future<Chat?> _reload(String chatId, Chat? chat, String belongTo) async {
//     if (chat == null) {
//       final query = QueryBuilder(
//         "chats",
//         where: "docId = ? AND belongTo = ?",
//         whereArgs: [chatId, belongTo],
//         limit: 1,
//       );
//       chat = await readFromLocalDatabase(query).then(
//         (chats) {
//           if (chats.isNotEmpty) {
//             return chats.first;
//           }
//           return null;
//         },
//       );
//     }

//     if (chat != null) {
//       final msgQuery = QueryBuilder(
//         "messages",
//         where: "chatId = ? AND belongTo = ? AND cluster = ?",
//         whereArgs: [chat.docId, belongTo, chat.clusters.last],
//         orderBy: "createdOn DESC",
//         limit: 1,
//       );

//       final lastMessage =
//           await MessagePool().cache.readFromLocalDatabase(msgQuery).then(
//         (msgs) {
//           if (msgs.isNotEmpty) {
//             return msgs.first;
//           }
//         },
//       );

//       chat = chat.copyWith(lastMessage: lastMessage);
//     }

//     return chat;
//   }

//   bool _hasReloadingScheduled = false;
//   void scheduleReloading() {
//     if (_hasReloadingScheduled || _needsReloading.isEmpty) return;
//     _reloadAll();
//   }

//   Future<void> _reloadAll() async {
//     if (kIsWeb) return;

//     final Map<String, Chat> chats = {};

//     final belongTo = getCurrentUser().id;

//     while (_needsReloading.isNotEmpty) {
//       final needsReload = _needsReloading;
//       _needsReloading = {};

//       final futures = <Future>[];

//       for (final entry in needsReload.entries) {
//         futures.add(
//           _reload(entry.key, entry.value, belongTo).then((chat) {
//             if (chat != null) {
//               chats[chat.docId] = chat;
//             }
//           }),
//         );
//       }
//       await Future.wait(futures);
//     }

//     _syncReloadingChats(chats.values.toList());
//   }

//   void _syncReloadingChats(List<Chat> chats) {
//     if (chats.isEmpty) return;

//     for (final chat in chats) {
//       _localChats[chat.docId] = chat;
//     }

//     if (!hasCommitScheduled) {
//       scheduleFlushUpdatesForUI();
//     }

//     _hasReloadingScheduled = false;
//   }
// }
