import 'package:cloud_firestore/cloud_firestore.dart';

import 'service_listener_manager.dart';
import 'base_cache.dart';

/// typically, [BaseService] would first translate the remote data into [T] events
/// then, using [BaseCache.dispatch] to dispatch events to the subscribers who subscribe to [BasePool.stream] for updating UI
/// [BaseService] only manage the [StreamSubscription]s that listen to the changes of firestore
/// the subclasses of [BaseService] should care how to dispatch events
abstract class BaseService<T extends BaseCache>
    with RemoteServiceListenerManager {
  final T cache;

  BaseService(this.cache);

  Future<void> initListeners() async {}

  void close() {
    cancelAllListeners();
  }
}

typedef QueryChange = QuerySnapshot<Map<String, dynamic>>;
typedef RemoteCollection = CollectionReference<Map<String, dynamic>>;
typedef CollectionChangeHandler = void Function(QueryChange);
