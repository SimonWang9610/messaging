import 'package:messaging/models/chat/chat.dart';
import 'package:messaging/services/friend/friend_pool.dart';

import '../base/base_pool.dart';
import 'chat_cache.dart';
import 'chat_service.dart';

class ChatPool extends BasePool<ChatCache, ChatService> {
  static final _instance = ChatPool._();
  ChatPool._();

  factory ChatPool() => _instance;

  @override
  void createCacheAndService() {
    cache = ChatCache(isBroadcast: true);
    service = ChatService(cache);
  }

  String? findChatName(Chat chat) {
    if (chat.members.length == 2) {
      final friend = FriendPool().findFriend(chat.membersHash);
      return friend.nickname ?? friend.username;
    }
  }
}
