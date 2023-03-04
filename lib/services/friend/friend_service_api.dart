import 'package:messaging/models/friend/friend.dart';
import 'package:messaging/models/friend/friend_status.dart';
import 'package:messaging/models/user.dart';
import 'package:messaging/services/base/base_service.dart';
import 'package:messaging/services/database.dart';
import 'package:messaging/services/friend/friend_cache.dart';
import 'package:messaging/services/service_helper.dart';
import 'package:messaging/utils/utils.dart';

// todo: delete/reject/block/blacklist friend
// todo: set nickname for friend
mixin FriendServiceApi on BaseService<FriendCache> {
  Future<void> addFriend(User user, {String? nickname}) async {
    final currentUser = cache.getCurrentUser();

    final docId = generateFriendDocId(currentUser.id, user.id);

    final selfName =
        "${Collection.user}/${currentUser.id}/${Collection.friend}";

    final otherName = "${Collection.user}/${user.id}/${Collection.friend}";

    final selfDoc = firestore.collection(selfName).doc(docId);
    final otherDoc = firestore.collection(otherName).doc(docId);

    final lastModified = DateTime.now().millisecondsSinceEpoch;

    try {
      final batch = firestore.batch();

      batch.set(
        selfDoc,
        {
          "docId": docId,
          "userId": user.id,
          "username": user.username,
          "email": user.email,
          "createdOn": lastModified,
          "lastModified": lastModified,
          "status": FriendStatus.pending.value,
          "createdBy": currentUser.id,
          if (nickname != null) "nickname": nickname,
        },
      );

      batch.set(
        otherDoc,
        {
          "docId": docId,
          "userId": currentUser.id,
          "username": currentUser.username,
          "email": currentUser.email,
          "createdOn": lastModified,
          "lastModified": lastModified,
          "createdBy": currentUser.id,
          "status": FriendStatus.pending.value,
        },
      );
      await batch.commit();
    } catch (e) {
      print(e);
      rethrow;
    }
  }

  /// when we want to accept an invitation
  /// 1) we first update self doc as [FriendStatus.accepted]
  /// 2) create a new doc for [Friend.userId]
  Future<void> accept(Friend friend, {String? nickname}) async {
    if (friend.status != FriendStatus.pending) return;

    final currentUser = cache.getCurrentUser();

    final selfName =
        "${Collection.user}/${currentUser.id}/${Collection.friend}";

    final otherName =
        "${Collection.user}/${friend.userId}/${Collection.friend}";

    final selfDoc = firestore.collection(selfName).doc(friend.docId);
    final otherDoc = firestore.collection(otherName).doc(friend.docId);

    final lastModified = DateTime.now().millisecondsSinceEpoch;
    final status = FriendStatus.accepted.value;

    try {
      final batch = firestore.batch();

      batch.update(selfDoc, {
        "status": status,
        "lastModified": lastModified,
        if (nickname != null) "nickname": "nickname",
      });

      batch.update(otherDoc, {
        "status": status,
        "lastModified": lastModified,
      });

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> getRemoteFriends() async {
    final currentUser = cache.getCurrentUser();
    final name = "${Collection.user}/${currentUser.id}/${Collection.friend}";
    final checkPoint = cache.getPoint(Constants.friendCheckPoint);

    QueryMap query = firestore.collection(name);

    if (checkPoint != null) {
      query = query.where("lastModified", isGreaterThan: checkPoint);
    }

    final docs = await query.get().then((snapshot) => snapshot.docs);

    final friends = docs
        .map(
          (doc) => Friend.fromMap(doc.data()),
        )
        .toList();
    await cache.syncRemoteFriends(friends);
  }

  Future<User?> searchUser(String email) async {
    final query = firestore
        .collection(Collection.user)
        .where("email", isEqualTo: email)
        .limit(1);

    final data = await query.get().then((snapshot) {
      if (snapshot.size > 0) {
        return snapshot.docs.first.data();
      } else {
        return null;
      }
    });

    if (data != null) {
      return User.fromMap(data);
    } else {
      return null;
    }
  }
}
