import 'package:flutter/foundation.dart';
import 'package:messaging/utils/utils.dart';

import 'package:sqflite/sqflite.dart';

import '../database_interface.dart';
import '../sql_builder.dart';
import '../schema.dart';

class _IoDatabase extends DatabaseInterface {
  static const dbName = "messaging.db";
  static final _instance = _IoDatabase._();

  _IoDatabase._();

  Database? _db;

  Database get db {
    assert(_db != null, "Must call init() before accessing [Database]");
    return _db!;
  }

  Future<void> init([bool dropAll = false]) async {
    if (_db == null) {
      final dbPath = await getDatabasesPath();

      _db = await openDatabase(
        "$dbPath/$dbName",
        version: 1,
        onConfigure: dropAll && kDebugMode ? _onConfigure : null,
        onCreate: _onCreate,
      );
    }
  }

  void _onCreate(Database db, int version) async {
    await db.transaction((txn) async {
      await Future.wait([
        txn.execute(Schema.friend),
        txn.execute(Schema.chat),
        txn.execute(Schema.message),
        txn.execute(Schema.checkPoints),
      ]);
    });
    print("create database");
  }

  void _onConfigure(Database db) async {
    await db.transaction((txn) async {
      final futures = <Future>[];

      Schema.debugDrops.forEach((sql) {
        futures.add(txn.execute(sql));
      });

      await Future.wait(futures);
      print("delete database");

      await Future.wait([
        txn.execute(Schema.friend),
        txn.execute(Schema.chat),
        txn.execute(Schema.message),
        txn.execute(Schema.checkPoints),
      ]);
      print("recreate database");
    });
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// [ConflictAlgorithm.replace] would delete the previous row when violating constraints
  /// and then insert the current data as a new row
  @override
  Future<void> update<T>(
    String table,
    List<T> data, {
    required ModelConverter<T> toDatabaseMap,
  }) async {
    try {
      print("upserting...$T");
      final batch = db.batch();

      for (final item in data) {
        batch.insert(
          table,
          toDatabaseMap(item),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit();
      print("completed: $T");
    } catch (e) {
      Log.e("Database.upsert error", e);
      rethrow;
    }
  }

  /// https://www.sqlite.org/lang_upsert.html
  /// UPSERT syntax was added to SQLite with version 3.24.0 (2018-06-04)
  /// for some devices it may not support UPSERTS
  /// https://github.com/tekartik/sqflite/issues/436
  @override
  Future<void> upsert<T>(
    List<T> data, {
    required UpsertBuilderFromData<T> upsertBuilder,
  }) async {
    try {
      print("raw upserting...");
      final batch = db.batch();

      for (final item in data) {
        final sql = upsertBuilder(item);
        batch.rawInsert(sql.sql, sql.arguments);
      }
      await batch.commit();
      print("completed: $T");
    } catch (e) {
      Log.e("Database.rawUpsert error", e);
      rethrow;
    }
  }

  @override
  Future<List<T>> load<T>(
    QueryBuilder query, {
    required ModelMapper<T> mapToModel,
  }) async {
    final data = <T>[];

    try {
      final result = await db.query(
        query.table,
        distinct: query.distinct,
        columns: query.columns,
        where: query.where,
        whereArgs: query.whereArgs,
        limit: query.limit,
        offset: query.offset,
        orderBy: query.orderBy,
        groupBy: query.groupBy,
        having: query.having,
      );

      print("loading data from local database....");
      for (final row in result) {
        print(row);
        final item = mapToModel(row);
        data.add(item);
      }
      print("data loaded");
    } catch (e) {
      print(e);
      Log.e("Database.load", e);
    }

    return data;
  }

  @override
  Future<void> delete<T>(
    List<T> data, {
    required ModelDeletionBuilder<T> deletionBuilder,
  }) async {
    try {
      print("deleting: $T");
      final batch = db.batch();

      for (final item in data) {
        final query = deletionBuilder(item);
        batch.delete(
          query.table,
          where: query.where,
          whereArgs: query.whereArgs,
        );
      }
      await batch.commit();
      print("delete completed");
    } catch (e) {
      print(e);
      Log.e("Database.delete", e);
    }
  }
}

DatabaseInterface getDatabase() => _IoDatabase._instance;
Future<void> initDatabase([bool dropAll = false]) =>
    _IoDatabase._instance.init(dropAll);
Future<void> closeDatabase() => _IoDatabase._instance.close();
