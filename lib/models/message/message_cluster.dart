import 'package:flutter/widgets.dart';

@immutable
class MessageCluster {
  final String path;
  final String chatId;

  const MessageCluster({
    required this.path,
    required this.chatId,
  });

  @override
  String toString() => 'MessageCluster(id: $path, chatId: $chatId)';

  @override
  bool operator ==(covariant MessageCluster other) {
    if (identical(this, other)) return true;

    return other.path == path && other.chatId == chatId;
  }

  @override
  int get hashCode => path.hashCode ^ chatId.hashCode;
}
