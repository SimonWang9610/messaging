import 'package:cloud_firestore/cloud_firestore.dart';

import 'service_listener_manager.dart';
import 'base_cache.dart';

/// typically, [BaseService] would first translate the remote data into [T] events in [handleFirestoreChange]
/// the subclasses of [BaseService] should care how to dispatch events in [handleFirestoreChange]
abstract class BaseService<T extends BaseCache>
    with RemoteServiceListenerManager {
  final T cache;

  BaseService(this.cache);

  Future<void> initListeners() async {}

  void close() {
    cancelAllListeners();
  }

  /// the subclasses should implement this method to invoke [BaseCache.dispatchAll]
  void handleFirestoreChange(QueryChange snapshot);
}

typedef QueryMap = Query<Map<String, dynamic>>;
typedef QueryChange = QuerySnapshot<Map<String, dynamic>>;
typedef RemoteCollection = CollectionReference<Map<String, dynamic>>;
typedef CollectionChangeHandler = void Function(QueryChange);
