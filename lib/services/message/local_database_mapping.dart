import 'package:messaging/models/message/models.dart';
import 'package:messaging/storage/sql_builder.dart';
import 'package:messaging/services/base/database_mapping.dart';

/// [belongTo] must be the current [User.id] or unique identity for the current user
mixin MessageDatabaseMapping on DatabaseMapping<Message> {
  @override
  Message mapToModel(Map<String, dynamic> row) => Message.fromMap(row);

  @override
  Map<String, dynamic> toDatabaseMap(data, belongTo) {
    final map = data.toMap();

    map["belongTo"] = belongTo;
    print("[toDatabaseMap]: $map");

    return map;
  }

  @override
  UpsertBuilder buildUpsertFromData(Message data, String belongTo) {
    final map = toDatabaseMap(data, belongTo);

    return UpsertBuilder(
      "messages",
      rowData: map,
      conflictColumns: ["docId", "chatId", "cluster", "belongTo"],
      conflictUpdates: {
        "lastModified": map["lastModified"],
        "status": map["status"],
      },
    );
  }

  @override
  DeleteBuilder buildDeletionFromData(Message data, String belongTo) {
    return DeleteBuilder(
      "messages",
      where: "docId = ? AND chatId = ? AND cluster = ? AND belongTo =?",
      whereArgs: [data.docId, data.chatId, data.cluster, belongTo],
    );
  }

  @override
  bool shouldDelete(Message data) => data.status == MessageStatus.deleted;
}
