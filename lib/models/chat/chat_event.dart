import 'chat.dart';
import '../operation.dart';

enum ClusterType {
  reserved('reserved'),
  personal('personal'),
  group('group');

  final String value;
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
