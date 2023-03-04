import 'package:messaging/utils/utils.dart';

import '../database_interface.dart';

class _WebDatabase extends DatabaseInterface {
  static final _instance = _WebDatabase._();
  _WebDatabase._();

  Future<void> init([bool dropAll = false]) async {
    Log.w(
        "Initializing [WebDatabase]. It actually does nothing and just for testing");
  }

  Future<void> close() async {
    Log.w(
        "Closing [WebDatabase]. It actually does nothing and just for testing");
  }
}

DatabaseInterface getDatabase() => _WebDatabase._instance;
Future<void> initDatabase([bool dropAll = false]) =>
    _WebDatabase._instance.init(dropAll);
Future<void> closeDatabase() => _WebDatabase._instance.close();
