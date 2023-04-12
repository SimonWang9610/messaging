import 'package:flutter/foundation.dart';
import 'package:messaging/services/base/check_point.dart';
import 'package:messaging/storage/database_interface.dart';

import 'package:messaging/storage/database_manager.dart';
import 'package:messaging/storage/sql_builder.dart';
import 'package:messaging/utils/utils.dart';

abstract class DatabaseMapping<T> {
  DatabaseInterface get db => DatabaseManager.getLocalDatabase();

  // todo: use [DatabaseInterface.upsert]
  Future<void> writeToLocalDatabase(
    String table, {
    required String belongTo,
    List<T> upserts = const [],
    List<T> deletions = const [],
  }) async {
    if (kIsWeb) return;

    try {
      final operations = <Future>[];
      if (upserts.isNotEmpty) {
        operations.add(
          db.update(
            table,
            upserts,
            toDatabaseMap: (data) => toDatabaseMap(data, belongTo),
          ),
        );
      }

      if (deletions.isNotEmpty) {
        operations.add(
          db.delete(
            deletions,
            deletionBuilder: (data) => buildDeletionFromData(data, belongTo),
          ),
        );
      }

      // await db.update(
      //   table,
      //   data,
      //   toDatabaseMap: toDatabaseMap,
      //   belongTo: belongTo,
      // );
      // await db.upsert(data, buildUpsertFromData: buildUpsertFromData);

      await Future.wait(operations);
    } catch (e) {
      Log.e("[writeToLocalDatabase] error", e);
    }
  }

  Future<List<T>> readFromLocalDatabase(QueryBuilder query) async {
    Log.i("$runtimeType: read from local database");
    if (kIsWeb) return [];

    final db = DatabaseManager.getLocalDatabase();

    try {
      return db.load(query, mapToModel: mapToModel);
    } catch (e) {
      Log.e("[readFromLocalDatabase] error", e);

      return [];
    }
  }

  Future<void> saveCheckpoint({
    required List<CheckPoint> points,
    required String belongTo,
  }) async {
    if (kIsWeb) return;

    try {
      Log.d("saving checkpoint: $points");
      return db.upsert<CheckPoint>(
        points,
        upsertBuilder: (point) {
          return UpsertBuilder(
            "checkPoints",
            rowData: {
              "id": point.id,
              "point": point.value,
              "belongTo": belongTo,
            },
            conflictColumns: ["id", "belongTo"],
            conflictUpdates: {
              "point": point.value,
            },
          );
        },
      );
    } catch (e) {
      Log.e("[saveCheckpoint] error", e);
    }
  }

  Future<int?> getCheckPoint(String key, String belongTo) async {
    if (kIsWeb) return null;

    final query = QueryBuilder(
      "checkPoints",
      columns: ["point"],
      where: "id = ? AND belongTo = ?",
      whereArgs: [key, belongTo],
      limit: 1,
    );

    try {
      final result = await db.load<int>(
        query,
        mapToModel: (row) => row["point"] as int,
      );

      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      Log.e("[getCheckPoint] error", e);

      return null;
    }
  }

  bool shouldDelete(T data) => false;

  /// when invoking [readFromLocalDatabase], it would convert the data into [T]
  T mapToModel(Map<String, dynamic> row);

  /// when invoking [writeToLocalDatabase], it would define how to map [T] into [Map]
  Map<String, dynamic> toDatabaseMap(T data, String belongTo);

  /// designed for [DatabaseInterface.upsert] that is implemented in storage/stub_entry/io_entry.dart
  UpsertBuilder buildUpsertFromData(T data, String belongTo);

  /// used for deleting multiple [T] in a batch
  DeleteBuilder buildDeletionFromData(T data, String belongTo);
}
