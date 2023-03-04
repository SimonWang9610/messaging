class Constants {
  static const contactCheckPoint = "contact-check-point";
  static const chatCheckPoint = "chat-check-point";
  static const friendCheckPoint = "friend-check-point";
}

class Collection {
  /// users/<userId>/sync-points/<chatId>
  static const sync = "sync-points";

  /// users/
  static const user = "users";

  /// chats/
  static const chat = "chats";

  /// contacts/
  static const contact = "contacts";

  /// users/<userid>/friends
  static const friend = "friends";

  /// message-clusters/<clusterId>/messages
  static const message = "messages";

  /// message-clusters/
  static const messageClusters = "message-clusters";

  static const clusterPrefix = "cluster";
}
