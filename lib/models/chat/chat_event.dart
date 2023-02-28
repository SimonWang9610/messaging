import 'chat.dart';
import '../operation.dart';

enum ClusterType {
  reserved(0),
  personal(1),
  group(2);

  final int value;
  const ClusterType(this.value);
}

class ChatEvent {
  final Operation operation;
  final String chatId;
  final Chat chat;

  ChatEvent({
    required this.operation,
    required this.chatId,
    required this.chat,
  });
}
