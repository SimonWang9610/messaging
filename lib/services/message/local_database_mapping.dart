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

  // @override
  // Future<void> writeToLocalDatabase(
  //   String table,
  //   List<Message> data, {
  //   required String belongTo,
  // }) async {
  //   Log.i("$runtimeType: write into local database");
  //   if (kIsWeb) return;

  //   final upserts = <Message>[];
  //   final deletions = <Message>[];

  //   for (final msg in data) {
  //     if (msg.status == MessageStatus.deleted) {
  //       deletions.add(msg);
  //     } else {
  //       upserts.add(msg);
  //     }
  //   }

  //   try {
  //     final operations = <Future>[];

  //     if (upserts.isNotEmpty) {
  //       operations.add(
  //         db.update(
  //           table,
  //           upserts,
  //           toDatabaseMap: (msg) => toDatabaseMap(msg, belongTo),
  //         ),
  //       );
  //     }

  //     if (deletions.isNotEmpty) {
  //       operations.add(
  //         db.delete(
  //           deletions,
  //           deletionBuilder: (msg) => buildDeletionFromData(msg, belongTo),
  //         ),
  //       );
  //     }

  //     await Future.wait(operations);
  //   } catch (e) {
  //     print(e);
  //   }
  // }
}
