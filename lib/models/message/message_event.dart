import 'message.dart';
import 'message_status.dart';
import '../operation.dart';

class MessageEvent {
  final Operation operation;
  final String msgId;
  final String chatId;
  final Message message;

  MessageEvent({
    required this.operation,
    required this.msgId,
    required this.chatId,
    required this.message,
  });

  String get id => message.uniqueId;

  MessageEvent copyWith({
    Message? message,
    bool? merged,
  }) {
    return MessageEvent(
      operation: operation,
      msgId: msgId,
      chatId: chatId,
      message: message ?? this.message,
    );
  }

  MessageEvent merge(MessageEvent? other) {
    if (other == null || chatId != other.chatId || msgId != other.msgId) {
      return this;
    }

    final statusOverride =
        operation == Operation.deleted || other.operation == Operation.deleted
            ? MessageStatus.deleted
            : null;

    return MessageEvent(
      operation: Operation.merge(operation, other.operation),
      msgId: msgId,
      chatId: chatId,
      message: message.merge(
        other.message,
        statusOverride: statusOverride,
      ),
    );
  }

  Message get finalMessage => message.copyWith(
        status: operation == Operation.deleted ? MessageStatus.deleted : null,
      );
}
