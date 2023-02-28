import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:messaging/utils/utils.dart';

import '../../models/chat/models.dart';
import '../../models/operation.dart';

import '../base/base_service.dart';
import '../base/base_cache.dart';

import '../database.dart';
import 'chat_cache.dart';
import 'chat_service_api.dart';

class ChatService extends BaseService<ChatCache> with ChatServiceApi {
  ChatService(super.cache);

  @override
  Future<void> initListeners() async {
    await getSyncPoints();
    _listenChatChange();
  }

  @override
  RemoteCollection get chats => Database.remote.collection(Collection.chat);

  /// only listen chats whose members contains the current user
  /// and [createdOn] is greater than the check point
  /// if the current device never sync with the firestore, the check point would be null
  /// for this case, the current device would sync all chats in firestore
  void _listenChatChange() {
    final checkPoint = CheckPointManager.get(Constants.chatCheckPoint);

    var query = chats
        .where(
          "members",
          arrayContains: cache.getCurrentUserEmail(),
        )
        .orderBy("lastModified");

    // if (checkPoint != null) {
    //   // for group chats, their members may change, so use 'lastModified' instead of 'createdOn'
    //   query = query.where(
    //     "lastModified",
    //     isGreaterThan: checkPoint,
    //   );
    // }

    final sub = query.snapshots().listen(
          _handleChatChange,
          onError: cache.dispatchError,
          onDone: () => removeListener("members"),
        );

    addListener("members", sub);
  }

  /// [ChatService] would only care those chats that have not been synced with the current device
  /// [Operation.updated] should be handled in [MessageService]
  /// besides, a new chat would be added into firestore only when the chat's initiator sends the first message
  void _handleChatChange(QueryChange snapshot) {
    final events = <ChatEvent>[];

    for (final change in snapshot.docChanges) {
      if (change.type != DocumentChangeType.removed) {
        final map = change.doc.data()!;
        print("chat change: $map");

        events.add(
          ChatEvent(
            operation: Operation.added,
            chatId: change.doc.id,
            chat: Chat.fromMap(map),
          ),
        );
      }

      cache.dispatchAll(events);
    }
  }
}
