import 'message.dart';
import 'message_status.dart';
import '../operation.dart';

class MessageEvent {
  final Operation operation;
  final String msgId;
  final String chatId;
  final bool merged;
  final Message message;

  MessageEvent({
    required this.operation,
    required this.msgId,
    required this.chatId,
    required this.message,
    this.merged = false,
  });

  String get id => "$chatId$msgId";

  MessageEvent copyWith({
    Message? message,
    bool? merged,
  }) {
    return MessageEvent(
      operation: operation,
      msgId: msgId,
      chatId: chatId,
      message: message ?? this.message,
      merged: merged ?? this.merged,
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
      merged: true,
    );
  }
}
