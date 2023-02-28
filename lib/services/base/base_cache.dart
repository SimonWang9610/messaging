import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import '../../utils/store.dart';

/// used to [dispatch] events created from [BaseService]
/// [eventEmitter] is created by [BasePool], so it should not be closed by [BaseCache]
/// some operations should be executed via [baseCache] once an event is [dispatch] instead of via [BaseService]
abstract class BaseCache<T, E> with CacheCommitScheduler {
  final StreamController<T> eventEmitter;

  BaseCache({bool isBroadcast = false})
      : eventEmitter = isBroadcast
            ? StreamController<T>.broadcast()
            : StreamController<T>();

  /// typically, the subclasses of [BaseCache] should care if [loadLocalCacheData] during [init]
  Future<void> init() async {}

  void dispatch(E event);

  void dispatchAll(List<E> events);

  /// dispatch error
  void dispatchError(Object error, [StackTrace? stackTrace]) {}

  String getCurrentUserEmail() {
    assert(LocalStorage.hasKey("userEmail"));
    return LocalStorage.read("userEmail");
  }

  String getCurrentUserId() {
    return LocalStorage.read("userId", useGlobal: true);
  }

  @mustCallSuper
  Future<void> close() async {
    _hasCommitScheduled.dispose();

    await eventEmitter.close();
  }

  /// when [BaseCache] is created by [BasePool.createCache]
  /// [init] would also be invoked to load local CacheData
  /// the subclasses of [BaseCache] may override this method to do something
  Future<void> loadLocalCacheData() async {}

  Stream<T> get stream => eventEmitter.stream;
}

typedef CommitAction = Future<bool> Function();
typedef AfterCommitAction = void Function(bool);

mixin CacheCommitScheduler {
  final ValueNotifier<bool> _hasCommitScheduled = ValueNotifier(false);

  bool get hasCommitScheduled => _hasCommitScheduled.value;

  Future<void> scheduleCommit(
    CommitAction action, {
    required AfterCommitAction afterCommitted,
    String? debugLabel,
  }) async {
    if (_hasCommitScheduled.value) return;

    _hasCommitScheduled.value = true;
    print("#########[COMMITTING] -> $debugLabel");

    final committed = await action();
    print("vvvvvvvvv[COMMITTED] -> $debugLabel");

    afterCommitted(committed);
    print(">>>>>>>>>[DISPATCH] -> $debugLabel");
    _hasCommitScheduled.value = false;
  }
}

class CheckPointManager {
  static Future<void> store(
    String key, {
    int? checkPoint,
    bool shouldFallback = false,
  }) async {
    final effectiveCheckPoint = checkPoint ??
        (shouldFallback ? DateTime.now().millisecondsSinceEpoch : null);
    await LocalStorage.write(key, effectiveCheckPoint);
  }

  static int? get(String key) {
    return LocalStorage.read(key);
  }
}
