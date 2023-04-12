import 'package:messaging/storage/sql_builder.dart';
import 'package:messaging/services/base/database_mapping.dart';
import 'package:messaging/models/friend/friend.dart';

mixin FriendDatabaseMapping on DatabaseMapping<Friend> {
  @override
  Friend mapToModel(Map<String, dynamic> row) => Friend.fromMap(row);

  @override
  Map<String, dynamic> toDatabaseMap(data, belongTo) {
    final map = data.toMap();

    map["belongTo"] = belongTo;
    print("[toDatabaseMap]: $map");

    return map;
  }

  @override
  UpsertBuilder buildUpsertFromData(Friend data, String belongTo) {
    final map = toDatabaseMap(data, belongTo);

    return UpsertBuilder(
      "friends",
      rowData: map,
      conflictColumns: ["docId", "belongTo"],
      conflictUpdates: {
        "email": map["email"],
        "username": map["username"],
        "lastModified": map["lastModified"],
        "status": map["status"],
        "nickname": map["nickname"],
      },
    );
  }

  @override
  DeleteBuilder buildDeletionFromData(Friend data, String belongTo) {
    return DeleteBuilder(
      "friends",
      where: "docId = ? AND belongTo = ?",
      whereArgs: [data.docId, belongTo],
    );
  }
}
