import 'package:messaging/storage/database_interface.dart';

import 'database_stub.dart'
    if (dart.library.io) './stub_entry/io_entry.dart'
    if (dart.library.html) './stub_entry/web_entry.dart';

class DatabaseManager {
  static DatabaseInterface getLocalDatabase() => getDatabase();
  static Future<void> initLocalDatabase([bool dropAll = false]) =>
      initDatabase(dropAll);
  static Future<void> closeLocalDatabase() => closeDatabase();
}
