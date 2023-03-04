import 'database_interface.dart';

DatabaseInterface getDatabase() => throw UnimplementedError(
    "current platform does not support local database");

Future<void> initDatabase([bool dropAll = false]) => throw UnimplementedError(
    "current platform does not support local database");

Future<void> closeDatabase() => throw UnimplementedError(
    "current platform does not support local database");
