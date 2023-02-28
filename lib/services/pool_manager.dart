import 'message/message_pool.dart';

import 'contact/contact_pool.dart';
import 'chat/chat_pool.dart';

class PoolManager {
  static final instance = PoolManager._();
  PoolManager._();

  /// must invoke after the user identity is known
  /// since all pools relies on the user identity to listen events only related to themselves
  /// [BaseCache.getCurrentUserEmail]
  Future<void> initPools() async {
    await Future.wait(
        [ContactPool().init(), ChatPool().init(), MessagePool().init()]);

    final localClusters = ChatPool().cache.clusters;
    MessagePool().bindClusters(localClusters);
  }

  Future<void> closePools() async {
    await Future.wait(
        [ContactPool().close(), ChatPool().close(), MessagePool().close()]);
  }
}
