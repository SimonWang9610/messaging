import 'package:get_storage/get_storage.dart';

class LocalStorage {
  static const global = "global";
  static const userSpace = "userId";

  static Future<void> init([String? userId]) async {
    await GetStorage.init(global);
    await GetStorage(global).write(userSpace, userId);

    if (userId != null) {
      await GetStorage.init(userId);
    }
  }

  static T? read<T>(String key, {bool useGlobal = false}) {
    final container = GetStorage(global);

    if (useGlobal) {
      return container.read(key) as T?;
    } else {
      final userId = container.read(userSpace);
      assert(userId != null, "No user space created");
      return GetStorage(userId).read(key) as T?;
    }
  }

  static Future<void> write(String key, dynamic value,
      {bool useGlobal = false}) async {
    final container = GetStorage(global);

    if (useGlobal) {
      return container.write(key, value);
    } else {
      final userId = container.read(userSpace);
      assert(userId != null, "No user space created");

      return GetStorage(userId).write(key, value);
    }
  }

  static bool hasKey(String key, {bool useGlobal = false}) {
    final container = GetStorage(global);

    if (useGlobal) {
      return container.hasData(key);
    } else {
      final userId = container.read(userSpace);
      assert(userId != null, "No user space created");
      return GetStorage(userId).hasData(key);
    }
  }

  static clear({bool onlyGlobal = true}) {
    print("local store clearing....");
    GetStorage(global).erase();

    if (!onlyGlobal) {
      GetStorage(userSpace).erase();
    }
  }
}
