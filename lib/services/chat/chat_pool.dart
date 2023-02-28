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
}
