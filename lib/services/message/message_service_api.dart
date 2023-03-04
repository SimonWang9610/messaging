import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:messaging/models/operation.dart';
import 'package:messaging/utils/constants.dart';

import '../../models/message/models.dart';

import '../base/base_service.dart';
import '../database.dart';
import 'message_cache.dart';

mixin MessageServiceApi on BaseService<MessageCache> {
  /// when the message is sent to firestore, [MessageCache.dispatch] would emit a [Message] whose status is [MessageStatus.sending]
  /// if the firestore adds the new [Message] successfully, it would emit the document change handled by [MessageService] directly
  /// if some errors happens, it turns out the [Message] failed to be sent
  void sendTextMessage(
    MessageCluster cluster, {
    required String text,
    String? quoteId,
  }) async {
    // todo: check if the receiver is the sender's friend

    final collection =
        firestore.collection("${cluster.path}/${Collection.message}");

    final docRef = collection.doc();

    final createdOn = DateTime.now().millisecondsSinceEpoch;
    final currentUser = cache.getCurrentUser();

    final message = {
      "docId": docRef.id,
      "sender": currentUser.id,
      "chatId": cluster.chatId,
      "createdOn": createdOn,
      "lastModified": createdOn,
      "status": MessageStatus.sent.value,
      "type": MessageType.text.value,
      "cluster": cluster.path,
      "body": text,
      if (quoteId != null) "quoteId": quoteId,
    };

    docRef.set(message).catchError(
      (err) {
        cache.dispatch(
          MessageEvent(
            operation: Operation.updated,
            msgId: docRef.id,
            chatId: cluster.chatId,
            message: Message.fromStatus(message, MessageStatus.failed),
          ),
        );
      },
    );

    cache.dispatch(
      MessageEvent(
        operation: Operation.added,
        msgId: docRef.id,
        chatId: cluster.chatId,
        message: Message.fromStatus(message, MessageStatus.sending),
      ),
    );
  }

  void resendMessage(Message message) {
    final collection =
        firestore.collection("${message.cluster}/${Collection.message}");

    final docRef = collection.doc(message.docId);

    final createdOn = DateTime.now().millisecondsSinceEpoch;

    final updatedMessage = message.copyWith(
      status: MessageStatus.sent,
      createdOn: createdOn,
      lastModified: createdOn,
    );

    docRef
        .set(
      updatedMessage.toMap(),
      SetOptions(merge: true),
    )
        .catchError((err) {
      cache.dispatch(
        MessageEvent(
          operation: Operation.updated,
          msgId: updatedMessage.docId,
          chatId: updatedMessage.chatId,
          message: updatedMessage.copyWith(status: MessageStatus.failed),
        ),
      );
    });

    cache.dispatch(
      MessageEvent(
        operation: Operation.added,
        msgId: updatedMessage.docId,
        chatId: updatedMessage.chatId,
        message: updatedMessage.copyWith(status: MessageStatus.sending),
      ),
    );
  }

  void rollbackMessage(Message message) async {
    final collection =
        firestore.collection("${message.cluster}/${Collection.message}");
    final docRef = collection.doc(message.docId);

    await docRef.delete();
  }
}
