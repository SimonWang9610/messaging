import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:messaging/models/user.dart';
import 'package:messaging/services/base/database_mapping.dart';
import 'package:messaging/utils/utils.dart';

/// used to [dispatch] events created from [BaseService]
abstract class BaseCache<T, E> with DatabaseMapping<T> {
  final StreamController<int> eventEmitter;
  final ValueNotifier<bool> _hasCommitScheduled = ValueNotifier(false);

  bool get hasCommitScheduled => _hasCommitScheduled.value;
  Stream<int> get stream => eventEmitter.stream;

  BaseCache({bool isBroadcast = false})
      : eventEmitter = isBroadcast
            ? StreamController<int>.broadcast()
            : StreamController<int>();

  /// typically, the subclasses of [BaseCache] should care if invoking [loadLocalCacheData] during [init]
  Future<void> init() async {}

  /// dispatch single/multiple [E] event
  /// [BaseCache] typically need to merge [E] event so as to avoid [scheduleFlushUpdatesForUI] repeatedly
  /// their implementations should invoke [scheduleCommit] to commit updates.deletions into local database
  void dispatch(E event);
  void dispatchAll(List<E> events);

  /// todo: dispatch error
  void dispatchError(Object error, [StackTrace? stackTrace]) {}

  /// 1) [scheduleCommit] if [hasCommitScheduled], it has no effect; otherwise it waits:
  /// 2) [commitUpdates] commit all updates/deletions into local database by invoking: [writeToLocalDatabase]
  /// 3) once [commitUpdates] completes, [afterCommit] is executed instantly
  Future<bool> commitUpdates();
  void afterCommit(bool committed);

  Future<void> scheduleCommit({
    String? debugLabel,
  }) async {
    if (_hasCommitScheduled.value) return;

    _hasCommitScheduled.value = true;
    Log.i("$debugLabel: ----------[committing]");

    final committed = await commitUpdates();
    Log.i("$debugLabel: ----------[updates committed]");

    afterCommit(committed);
    Log.i("$debugLabel: ----------[would notify UI]");

    _hasCommitScheduled.value = false;
  }

  void scheduleFlushUpdatesForUI() {
    SchedulerBinding.instance.endOfFrame.then(
      (_) => notifyCacheChange(),
    );
  }

  /// it it is the duty of subclasses of [BaseCache] to define how to notify UI the changes of cached data
  void notifyCacheChange();

  @mustCallSuper
  Future<void> close() async {
    _hasCommitScheduled.dispose();

    await eventEmitter.close();
  }

  User getCurrentUser() {
    final map = LocalStorage.read("user", useGlobal: true);
    return User.fromMap(json.decode(map) as Map<String, dynamic>);
  }
}
