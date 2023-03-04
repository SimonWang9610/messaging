import 'package:messaging/models/friend/friend.dart';
import 'package:messaging/services/base/base_pool.dart';
import 'package:messaging/services/friend/friend_cache.dart';
import 'package:messaging/services/friend/friend_service.dart';

class FriendPool extends BasePool<FriendCache, FriendService> {
  static final _instance = FriendPool._();
  FriendPool._();

  factory FriendPool() => _instance;

  @override
  void createCacheAndService() {
    cache = FriendCache();
    service = FriendService(cache);
  }

  Friend findFriend(String membersHash) {
    return cache.findFriend(membersHash);
  }
}
