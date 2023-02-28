import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  static const dbName = "messaging.db";

  static final _instance = LocalDatabase._();
  LocalDatabase._();

  factory LocalDatabase() => _instance;

  Database? _db;

  void init() async {
    if (_db == null) {
      final dbPath = await getDatabasesPath();

      _db = await openDatabase("$dbPath/$dbName");
    }
  }

  void _onCreate(Database db, int version) async {}
}
