import 'package:messaging/utils/utils.dart';

import '../../models/chat/models.dart';
import '../../models/message/models.dart';
import '../base/base_pool.dart';
import 'message_cache.dart';
import 'message_service.dart';

/// [init] would do something sequentially
/// 1) [close] previous [service] and [cache]
/// 2) [createCacheAndService]
/// 3) wait [cache.init] completed
/// 4) wait [MessageService.initListeners] completed.
/// if no init [MessageCluster] provided, [MessageService.initListeners] actually do nothing.
/// therefore, [ChatPool] should manually invoke [bindClusters] to listen to all [Chat]s updates
class MessagePool extends BasePool<MessageCache, MessageService> {
  static final _instance = MessagePool._();
  MessagePool._();

  factory MessagePool() => _instance;

  @override
  void createCacheAndService() {
    cache = MessageCache();
    service = MessageService(cache);
  }

  Stream<int> subscribe(Chat chat) {
    Log.i("start chatting with ${chat.id}");

    cache.subscribe(chat);
    service.refreshCluster(
      MessageCluster(path: chat.clusters.last, chatId: chat.id),
    );
    return cache.stream;
  }

  void unsubscribe() {
    cache.unsubscribe();
  }

  void bindClusters(List<MessageCluster> clusters) {
    for (final cluster in clusters) {
      service.addCluster(cluster);
    }
  }

  List<Message> get historyMessages => cache.historyMessages;
  List<Message> get newMessages => cache.newMessages;
}
