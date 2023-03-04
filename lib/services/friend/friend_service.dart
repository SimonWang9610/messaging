import 'package:messaging/models/friend/friend.dart';
import 'package:messaging/models/friend/friend_event.dart';
import 'package:messaging/services/base/base_service.dart';
import 'package:messaging/services/database.dart';
import 'package:messaging/services/friend/friend_cache.dart';
import 'package:messaging/services/friend/friend_service_api.dart';
import 'package:messaging/services/service_helper.dart';
import 'package:messaging/utils/utils.dart';

// todo: enable check point with sqlite
class FriendService extends BaseService<FriendCache> with FriendServiceApi {
  FriendService(super.cache);

  @override
  Future<void> initListeners() async {
    await getRemoteFriends();
    _listenFriendChange(handleFirestoreChange);
  }

  void _listenFriendChange(CollectionChangeHandler handler) {
    final checkPoint = cache.getPoint(Constants.friendCheckPoint);

    final currentUser = cache.getCurrentUser();
    final collectionName =
        "${Collection.user}/${currentUser.id}/${Collection.friend}";
    QueryMap query = firestore.collection(collectionName);

    if (checkPoint != null) {
      print(
          "friend service: ${DateTime.fromMillisecondsSinceEpoch(checkPoint)}");
      query = query.where("lastModified", isGreaterThan: checkPoint);
    }

    final sub = query.snapshots().listen(
          handler,
          onError: cache.dispatchError,
          onDone: () => removeListener("friends"),
        );

    addListener("friends", sub);
  }

  @override
  void handleFirestoreChange(QueryChange snapshot) {
    final events = <FriendEvent>[];

    for (final change in snapshot.docChanges) {
      final operation = mapToOperation(change.type);

      final map = change.doc.data();
      print("[FRIEND] change: $map");

      events.add(
        FriendEvent(
          operation: operation,
          docId: change.doc.id,
          friend: Friend.fromMap(map!),
        ),
      );
    }

    if (events.isNotEmpty) {
      cache.dispatchAll(events);
    }
  }
}
