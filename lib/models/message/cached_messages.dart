import 'message.dart';

enum CachedType {
  history,
  updates,
}

class CachedMessages {
  final CachedType type;
  final List<Message> messages;

  const CachedMessages({
    required this.type,
    required this.messages,
  });
}
