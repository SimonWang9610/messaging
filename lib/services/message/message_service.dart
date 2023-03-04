import 'dart:async';

import 'package:messaging/services/service_helper.dart';
import 'package:messaging/utils/utils.dart';

import '../../models/message/models.dart';

import '../base/base_service.dart';
import '../database.dart';

import 'message_cache.dart';
import 'message_service_api.dart';

// todo: enable check point with sqlite

class MessageService extends BaseService<MessageCache> with MessageServiceApi {
  MessageService(super.cache, {List<MessageCluster>? clusters})
      : _clusters = clusters ?? [];

  @override
  Future<void> initListeners() async {
    for (final cluster in _clusters) {
      _listenClusterChange(cluster);
    }
  }

  @override
  void close() {
    for (final cluster in _clusters) {
      removeListener(cluster.path);
    }
    _clusters.clear();
    super.close();
  }

  late List<MessageCluster> _clusters;

  void addCluster(MessageCluster cluster) {
    if (!_clusters.contains(cluster)) {
      removeListener(cluster.path);
      _clusters.add(cluster);
      _listenClusterChange(cluster);
      Log.i("listen chat cluster: ${cluster.chatId}");
    }
  }

  void refreshCluster(MessageCluster cluster) {
    removeListener(cluster.path);

    if (!_clusters.contains(cluster)) {
      _clusters.add(cluster);
    }
    _listenClusterChange(cluster);
  }

  void removeClusterByChatId(String chatId) {
    for (final cluster in _clusters) {
      if (cluster.chatId == chatId) {
        removeListener(cluster.path);
      }
    }
  }

  /// the collection would be 'message-clusters/cluster-<type>-<count>/messages'
  /// [MessageCluster.path] would be 'message-clusters/cluster-<type>-<count>'
  ///
  /// if the current device has checked some messages, we only need to load those messages that
  /// 1) belong to [messageCluster]
  /// 2) modified after the check point
  /// if using createdOn to filter messages, we cannot detect the changes happened after the check point
  /// e.g., we cannot know whether messages are read or loaded because those messages may be created before the check point
  /// consequently, the createdOn filter would never push updates related to such messages
  void _listenClusterChange(MessageCluster messageCluster) {
    final checkPoint =
        cache.getPoint("${Constants.chatCheckPoint}-${messageCluster.chatId}");

    var query = firestore
        .collection("${messageCluster.path}/${Collection.message}")
        .where("chatId", isEqualTo: messageCluster.chatId);

    if (checkPoint != null) {
      print(
          "message service: ${DateTime.fromMillisecondsSinceEpoch(checkPoint)}");

      query = query.where("lastModified", isGreaterThan: checkPoint);
    }

    final sub = query.snapshots().listen(
          handleFirestoreChange,
          onError: cache.dispatchError,
          onDone: () => removeListener(messageCluster.path),
        );

    addListener(messageCluster.path, sub);
  }

  // ? if change type is [DocumentType.removed], change.doc.data() would return the deleted data?
  @override
  void handleFirestoreChange(QueryChange snapshot) {
    final events = <MessageEvent>[];
    // todo: filter some kinds of [MessageEvent] to reduce the complexity
    for (final change in snapshot.docChanges) {
      final operation = mapToOperation(change.type);

      final map = change.doc.data()!;

      print("[MESSAGE] change: $map, deleted: $operation");

      events.add(
        MessageEvent(
          operation: operation,
          msgId: change.doc.id,
          chatId: map["chatId"],
          message: Message.fromMap(map),
        ),
      );
    }

    if (events.isNotEmpty) {
      cache.dispatchAll(events);
    }
  }
}
