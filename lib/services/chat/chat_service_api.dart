import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:messaging/models/message/message.dart';
import 'package:messaging/models/message/message_status.dart';
import 'package:messaging/utils/utils.dart';

import '../../models/chat/models.dart';
import '../../models/operation.dart';

import '../base/base_service.dart';
import '../service_helper.dart';
import '../database.dart';

import 'chat_cache.dart';

/// [ChatServiceApi] should only handle the logics of querying firestore directly
/// the logics of listening to the document changes of firestore should be implemented in [ChatService]
mixin ChatServiceApi on BaseService<ChatCache> {
  RemoteCollection get chats;

  Future<Chat> startPrivateChat(String userId) async {
    final currentUser = cache.getCurrentUser();
    final sortedMembers = sortChatMembers([userId, currentUser.id]);

    final membersHash = hashMembers(sortedMembers);

    Chat? chat = cache.findChatByHash(membersHash);

    if (chat == null) {
      final snapshot = await chats
          .where("membersHash", isEqualTo: membersHash)
          .limit(1)
          .get()
          .then(
        (snapshot) {
          if (snapshot.size > 0) {
            return snapshot.docs.first;
          } else {
            return null;
          }
        },
      );

      if (snapshot != null) {
        final map = snapshot.data();
        final remoteChat = Chat.fromMap(map);
        cache.dispatch(
          ChatEvent(
            operation: Operation.added,
            chatId: snapshot.id,
            chat: remoteChat,
          ),
        );
        return remoteChat;
      } else {
        final doc = chats.doc();
        final createdOn = DateTime.now().millisecondsSinceEpoch;

        final clusterPath = _assignClusterFor(
            Collection.messageClusters, ClusterType.personal, doc.id);

        final chatMap = {
          "docId": doc.id,
          "createdOn": createdOn,
          "lastModified": createdOn,
          "members": sortedMembers,
          "membersHash": membersHash,
          "cluster": clusterPath,
        };

        await doc.set(
          chatMap,
          SetOptions(merge: true),
        );
        return Chat.fromMap(chatMap);
      }
    } else {
      return chat;
    }
  }

  /// because we may ack those history messages
  /// so we must ensure [lastSync] is not decreased
  Future<SyncPoint> syncChat(String chatId, Message lastMessage) async {
    final currentUser = cache.getCurrentUser();
    final collection =
        firestore.collection("users/${currentUser.id}/${Collection.sync}");

    final docRef = collection.doc(chatId);

    final oldPoint = await docRef.get().then((snapshot) => snapshot.data());

    final maxLastSync = oldPoint == null
        ? lastMessage.createdOn
        : max(oldPoint["lastSync"]! as int, lastMessage.createdOn);

    final map = {
      "chatId": chatId,
      "msgId": lastMessage.docId,
      "lastSync": maxLastSync,
      "lastModified": DateTime.now().millisecondsSinceEpoch,
    };

    await docRef.set(
      map,
      SetOptions(merge: true),
    );
    return SyncPoint.fromMap(map);
  }

  // todo: ?it would conflict if acking a message while the message is deleting at the same time
  /// first update messages according to their clusters
  /// then, update the sync point for the chat
  Future<SyncPoint> ackMessages(List<Message> messages) async {
    assert(_debugCheckMessageStatus(messages),
        "Current user can only ack messages that are not sent by self and waiting read");

    final clusters = <String, List<Message>>{};
    Message lastMessage = messages.first;
    String chatId = lastMessage.chatId;

    for (final msg in messages) {
      assert(msg.chatId == chatId,
          "Cannot ack messages that belong to different chats");

      if (clusters.containsKey(msg.cluster)) {
        clusters[msg.cluster]!.add(msg);
      } else {
        clusters[msg.cluster] = [msg];
      }

      lastMessage = lastMessage.compareCreatedOn(msg);
    }

    final batch = firestore.batch();
    final lastModified = DateTime.now().millisecondsSinceEpoch;

    for (final entry in clusters.entries) {
      final path = getMessageCollectionPath(entry.key);

      final collection = firestore.collection(path);

      entry.value.forEach((msg) {
        batch.update(collection.doc(msg.docId), {
          "status": MessageStatus.read.value,
          "lastModified": lastModified,
        });
      });
    }

    await batch.commit();

    return syncChat(chatId, lastMessage);
  }

  Future<SyncPoint?> ackAllHistoryMessages(Chat chat) async {
    if (chat.syncPoint == null) return null;

    SyncPoint? point;

    final currentUser = cache.getCurrentUser();

    final path = getMessageCollectionPath(chat.cluster);

    final collection = firestore.collection(path);
    final query = collection
        .orderBy("createdOn")
        .where("createdOn", isGreaterThanOrEqualTo: chat.syncPoint!.lastSync)
        .where(
          "createdOn",
          isLessThan: DateTime.now(),
        )
        .where("status", isEqualTo: MessageStatus.sent)
        .where(
          "sender",
          isNotEqualTo: currentUser.id,
        );

    final docs = await query.get().then((snapshot) => snapshot.docs);

    final batch = firestore.batch();
    final lastModified = DateTime.now().millisecondsSinceEpoch;

    Map<String, dynamic>? msg;

    for (final doc in docs) {
      msg = doc.data();

      batch.update(doc.reference, {
        "status": MessageStatus.read.value,
        "lastModified": lastModified,
      });
    }

    await batch.commit();

    if (msg != null) {
      point = await syncChat(chat.docId, Message.fromMap(msg));
    }

    return point;
  }

  Future<void> getSyncPoints() async {
    final currentUser = cache.getCurrentUser();

    final collection =
        firestore.collection("users/${currentUser.id}/${Collection.sync}");

    final checkPoint = cache.getPoint(Constants.chatCheckPoint);

    QuerySnapshot<Map<String, dynamic>> snapshot;

    if (checkPoint != null) {
      final query = collection.where(
        "lastModified",
        isGreaterThan: checkPoint,
      );

      snapshot = await query.get();
    } else {
      snapshot = await collection.get();
    }
    snapshot = await collection.get();

    final syncPointsMap = snapshot.docs.map((doc) => doc.data()).toList();

    await cache.updateSyncPoints(syncPointsMap);
  }

  // Future<String> assignChatCluster([ClusterType type = ClusterType.private]) =>
  //     _assignClusterFor(chatCluster, type);

  String _assignClusterFor(
      String collectionName, ClusterType type, String chatDocId) {
    final collection = firestore.collection(collectionName);

    final seq = hashChatIdForCollection(chatDocId);

    final path = "${type.value}-$seq";

    final doc = collection.doc(path);

    return doc.id;
  }

  bool _debugCheckMessageStatus(List<Message> messages) {
    final currentUser = cache.getCurrentUser();

    for (final message in messages) {
      if (message.status != MessageStatus.sent ||
          message.sender == currentUser.id) {
        return false;
      }
    }
    return true;
  }
}
