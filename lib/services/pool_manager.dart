import 'package:messaging/services/friend/friend_pool.dart';

import 'message/message_pool.dart';

import 'chat/chat_pool.dart';

class PoolManager {
  /// must invoke after the user identity is known
  /// since all pools relies on the user identity to listen events only related to themselves
  /// [BaseCache.getCurrentUserEmail]
  static Future<void> initPools() async {
    await FriendPool().init();

    await Future.wait([ChatPool().init(), MessagePool().init()]);

    final localClusters = ChatPool().cache.clusters;
    MessagePool().bindClusters(localClusters);
  }

  static Future<void> closePools() async {
    await Future.wait(
        [FriendPool().close(), ChatPool().close(), MessagePool().close()]);
  }
}
