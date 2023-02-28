import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:messaging/models/chat/sync_point.dart';
import 'package:messaging/models/message/message.dart';
import 'package:messaging/models/message/message_cluster.dart';
import 'package:messaging/models/message/message_status.dart';
import 'package:messaging/utils/utils.dart';

import '../../models/chat/models.dart';
import '../../models/operation.dart';

import '../base/base_service.dart';
import '../base/base_cache.dart';
import '../service_helper.dart';
import '../database.dart';

import 'chat_cache.dart';

/// [ChatServiceApi] should only handle the logics of querying firestore directly
/// the logics of listening to the document changes of firestore should be implemented in [ChatService]
mixin ChatServiceApi on BaseService<ChatCache> {
  RemoteCollection get chats;

  Future<Chat> startPrivateChat(String email) async {
    final sortedMembers = sortChatMembers([email, cache.getCurrentUserEmail()]);

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

        final clusterPath = await _assignMessageCluster();
        final chatMap = {
          "id": doc.id,
          "createdOn": createdOn,
          "lastModified": createdOn,
          "members": sortedMembers,
          "membersHash": membersHash,
          "clusters": [clusterPath],
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
    final collection = Database.remote
        .collection("users/${cache.getCurrentUserId()}/${Collection.sync}");

    final docRef = collection.doc(chatId);

    final oldPoint = await docRef.get().then((snapshot) => snapshot.data());

    final maxLastSync = oldPoint == null
        ? lastMessage.createdOn
        : max(oldPoint["lastSync"]! as int, lastMessage.createdOn);

    final map = {
      "chatId": chatId,
      "msgId": lastMessage.id,
      "lastSync": maxLastSync,
      "lastModified": DateTime.now().millisecondsSinceEpoch,
    };

    await docRef.set(
      map,
      SetOptions(merge: true),
    );
    return SyncPoint.fromMap(map);
  }

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

    final batch = Database.remote.batch();
    final lastModified = DateTime.now().millisecondsSinceEpoch;

    for (final entry in clusters.entries) {
      final collection =
          Database.remote.collection("${entry.key}/${Collection.message}");

      entry.value.forEach((msg) {
        batch.update(collection.doc(msg.id), {
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

    for (final cluster in chat.clusters) {
      final collection =
          Database.remote.collection("$cluster/${Collection.message}");
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
            isNotEqualTo: cache.getCurrentUserEmail(),
          );

      final docs = await query.get().then((snapshot) => snapshot.docs);

      final batch = Database.remote.batch();
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
        point = await syncChat(chat.id, Message.fromMap(msg));
      }
    }
    return point;
  }

  Future<void> getSyncPoints() async {
    final collection = Database.remote
        .collection("users/${cache.getCurrentUserId()}/${Collection.sync}");

    final checkPoint = CheckPointManager.get(Constants.chatCheckPoint);

    QuerySnapshot<Map<String, dynamic>> snapshot;

    // if (checkPoint != null) {
    //   final query = collection.where(
    //     "lastModified",
    //     isGreaterThan: cache.getLastCheckPoint(),
    //   );

    //   snapshot = await query.get();
    // } else {
    //   snapshot = await collection.get();
    // }
    snapshot = await collection.get();

    final syncPointsMap = snapshot.docs.map((doc) => doc.data()).toList();

    await cache.updateSyncPoints(syncPointsMap);
  }

  /// see [ClusterType]
  Future<String> _assignMessageCluster(
          [ClusterType type = ClusterType.personal]) =>
      _assignClusterFor(Collection.messageClusters, type);

  // Future<String> assignChatCluster([ClusterType type = ClusterType.private]) =>
  //     _assignClusterFor(chatCluster, type);

  Future<String> _assignClusterFor(
      String collectionName, ClusterType type) async {
    final collection = Database.remote.collection(collectionName);

    final query = collection
        .orderBy("capacity", descending: true)
        .where("capacity", isGreaterThan: 0)
        .where("type", isEqualTo: type.value)
        .limit(1);

    var docRef = await query.get().then((snapshot) {
      if (snapshot.size > 0) {
        return snapshot.docs.first.reference;
      } else {
        return null;
      }
    });

    if (docRef == null) {
      final clusterCount =
          await collection.count().get().then((snapshot) => snapshot.count);
      final clusterId = createClusterId(Collection.clusterPrefix,
          type: type, count: clusterCount + 1);

      docRef = collection.doc(clusterId);
    }

    final clusterData = await docRef.get().then((snapshot) => snapshot.data());

    final capacity =
        (clusterData?["capacity"] as int?) ?? getCapacityByType(type);
    final clusterType = (clusterData?["type"] as int?) ?? type.value;

    assert(_debugCheckClusterType(docRef.id, clusterType),
        "${docRef.id} not follow [cluster-<type>-<count>] rule");

    await docRef.set(
      {
        "capacity": capacity - 1,
        "type": clusterType,
      },
      SetOptions(merge: true),
    );
    return docRef.path;
  }

  bool _debugCheckClusterType(String clusterId, int type) {
    final splits = clusterId.split("-");

    if (splits.length != 3) {
      print("$clusterId not follow [cluster-type-count] rule");
      return false;
    } else {
      return int.tryParse(splits[1]) == type;
    }
  }

  int getCapacityByType(ClusterType type) {
    switch (type) {
      case ClusterType.reserved:
        return 100;
      case ClusterType.personal:
        return 10000;
      case ClusterType.group:
        return 500;
    }
  }

  bool _debugCheckMessageStatus(List<Message> messages) {
    for (final message in messages) {
      if (message.status != MessageStatus.sent ||
          message.sender == cache.getCurrentUserEmail()) {
        return false;
      }
    }
    return true;
  }
}
