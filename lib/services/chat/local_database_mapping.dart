import 'dart:convert';

import 'package:messaging/models/message/models.dart';
import 'package:messaging/storage/sql_builder.dart';

import '../../models/chat/models.dart';
import '../base/database_mapping.dart';

mixin ChatDatabaseMapping on DatabaseMapping<Chat> {
  @override
  Chat mapToModel(Map<String, dynamic> row) {
    final members = (row["members"] as String)
        .split(",")
        .where((element) => element.isNotEmpty)
        .toList();

    final syncPointMap = row["syncPoint"] != null
        ? json.decode(row["syncPoint"] as String) as Map<String, dynamic>
        : null;

    final lastMessageMap = row["lastMessage"] != null
        ? json.decode(row["lastMessage"] as String) as Map<String, dynamic>
        : null;

    final clusters = (row["clusters"] as String)
        .split(",")
        .where((element) => element.isNotEmpty)
        .toList();

    return Chat(
      docId: row['docId'] as String,
      createdOn: row['createdOn'] as int,
      lastModified: row['lastModified'] as int,
      members: members,
      clusters: clusters,
      membersHash: row['membersHash'] as String,
      syncPoint: syncPointMap != null ? SyncPoint.fromMap(syncPointMap) : null,
      lastMessage:
          lastMessageMap != null ? Message.fromMap(lastMessageMap) : null,
      unread: row["unread"] as int,
    );
  }

  @override
  Map<String, dynamic> toDatabaseMap(data, belongTo) {
    final map = data.toMap();

    map["belongTo"] = belongTo;

    map["members"] = data.members.join(",");
    map["syncPoint"] =
        data.syncPoint != null ? json.encode(data.syncPoint?.toMap()) : null;

    map["clusters"] = data.clusters.join(",");
    map["lastMessage"] = data.lastMessage != null
        ? json.encode(data.lastMessage?.toMap())
        : null;

    print("[toDatabaseMap]: $map");

    return map;
  }

  @override
  UpsertBuilder buildUpsertFromData(Chat data, String belongTo) {
    final map = toDatabaseMap(data, belongTo);

    return UpsertBuilder(
      "chats",
      rowData: map,
      conflictColumns: ["docId", "belongTo", "membersHash"],
      conflictUpdates: {
        "syncPoint": map["syncPoint"],
        "lastMessage": map["lastMessage"],
        "members": map["members"],
        "clusters": map["clusters"],
      },
    );
  }

  @override
  DeleteBuilder buildDeletionFromData(Chat data, String belongTo) {
    return DeleteBuilder(
      "chats",
      where: "docId = ? AND membersHash = ? AND belongTo = ?",
      whereArgs: [data.docId, data.membersHash, belongTo],
    );
  }
}
