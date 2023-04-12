import 'dart:math';

import 'package:messaging/models/friend/friend.dart';
import 'package:messaging/models/friend/friend_event.dart';
import 'package:messaging/models/friend/friend_status.dart';
import 'package:messaging/services/base/base_cache.dart';
import 'package:messaging/services/base/check_point.dart';
import 'package:messaging/services/friend/local_database_mapping.dart';
import 'package:messaging/storage/sql_builder.dart';
import 'package:messaging/utils/utils.dart';

class FriendCache extends BaseCache<Friend, FriendEvent>
    with FriendDatabaseMapping {
  FriendCache({super.isBroadcast = false});

  /// key: [Friend.docId]
  final Map<String, Friend> _localFriends = {};

  /// key: [Friend.docId]
  Map<String, Friend> _waitingCommit = {};

  List<Friend> get friends => _localFriends.values.toList();

  int? _latterLastModified;

  @override
  Future<void> init() async {
    final currentUser = getCurrentUser();
    final query = QueryBuilder(
      "friends",
      where: "belongTo = ?",
      whereArgs: [currentUser.id],
    );

    final friends = await readFromLocalDatabase(query);

    friends.forEach((element) {
      _localFriends[element.docId] = element;
    });

    _latterLastModified =
        await getCheckPoint(Constants.friendCheckPoint, currentUser.id);
  }

  @override
  void dispatchAll(events) {
    for (final event in events) {
      _syncLocalFriend(event.friend);
    }

    scheduleCommit(debugLabel: "[FriendCache].dispatchAll");
  }

  @override
  void dispatch(event) {
    _syncLocalFriend(event.friend);
    scheduleCommit(debugLabel: "[FriendCache].dispatch");
  }

  @override
  Future<bool> commitUpdates() async {
    bool updatesCommitted = false;

    int? lastModified;

    while (_waitingCommit.isNotEmpty) {
      final friends = _waitingCommit;
      _waitingCommit = {};

      final upserts = <Friend>[];
      final deletions = <Friend>[];

      friends.values.forEach((friend) {
        if (friend.status == FriendStatus.deleted) {
          deletions.add(friend);
        } else {
          if (_localFriends[friend.docId] != friend) {
            upserts.add(friend);
          }
        }

        if (lastModified == null) {
          lastModified = friend.lastModified;
        } else {
          lastModified = max(lastModified!, friend.lastModified);
        }
      });

      await writeToLocalDatabase(
        "friends",
        upserts: upserts,
        deletions: deletions,
        belongTo: getCurrentUser().id,
      );

      for (final deleted in deletions) {
        _localFriends.remove(deleted.docId);
      }

      for (final updated in upserts) {
        _localFriends[updated.docId] = updated;
      }

      _latterLastModified = lastModified;

      updatesCommitted = true;
    }
    return updatesCommitted;
  }

  @override
  void afterCommit(committed) {
    if (committed) {
      saveCheckpoint(
        points: [CheckPoint(Constants.friendCheckPoint, _latterLastModified!)],
        belongTo: getCurrentUser().id,
      );
      scheduleFlushUpdatesForUI();
    }
  }

  @override
  void notifyCacheChange() {
    if (!eventEmitter.isClosed && _latterLastModified != null) {
      eventEmitter.add(DateTime.now().millisecondsSinceEpoch);
    }
  }

  /// since we fetch remote data actively
  /// so we should [storePoint] here
  /// avoid retrieving redundant data when [FriendService] listens to /friends collection
  Future<void> syncRemoteFriends(List<Friend> friends) async {
    int? lastModified;

    for (final friend in friends) {
      _syncLocalFriend(friend);

      if (lastModified == null) {
        lastModified = friend.lastModified;
      } else {
        lastModified = max(lastModified, friend.lastModified);
      }
    }

    if (lastModified != null) {
      await saveCheckpoint(
        points: [CheckPoint(Constants.friendCheckPoint, lastModified)],
        belongTo: getCurrentUser().id,
      );
    }

    scheduleCommit(debugLabel: "[FriendCache].syncRemoteFriends");
  }

  void _syncLocalFriend(Friend? friend, {bool forceSync = false}) {
    if (friend == null) return;

    final localFriend = _localFriends[friend.docId];

    final syncedFriend = friend.merge(localFriend);

    if (localFriend != syncedFriend || forceSync) {
      _waitingCommit[syncedFriend.docId] = syncedFriend;
    } else {
      _localFriends[syncedFriend.docId] = syncedFriend;
    }
  }

  bool isFriend(String? membersHash) {
    final friend = _localFriends[membersHash];
    return friend?.status == FriendStatus.accepted;
  }

  Friend findFriend(String membersHash) {
    return _localFriends[membersHash]!;
  }
}
