import 'dart:async';
import 'package:messaging/utils/utils.dart';
import 'package:meta/meta.dart';

import 'base_cache.dart';
import 'base_service.dart';

abstract class BasePool<C extends BaseCache, S extends BaseService<C>> {
  C? _cache;

  C get cache {
    assert(_cache != null, "Must call init() to initialized $runtimeType");
    return _cache!;
  }

  set cache(C value) {
    if (initialized) return;
    _cache = value;
  }

  S? _service;
  S get service {
    assert(initialized, "Must call init() before using [BaseService]");
    return _service!;
  }

  set service(S value) {
    if (initialized) return;
    _service = value;
  }

  bool get initialized => _cache != null && _service != null;

  @mustCallSuper
  Future<void> init() async {
    if (initialized) return;

    Log.i("$runtimeType initializing>>>>>>>>>>>");

    await close();

    createCacheAndService();
    // Log.i("[Cache]: ${_cache.runtimeType} starting---");

    await _cache!.init();
    // Log.i("[Cache]: ${_cache.runtimeType} started---");

    // Log.i("[Service]: ${_service.runtimeType} starting...");
    await _service!.initListeners();
    // Log.i("[Service]: ${_service.runtimeType} started...");

    Log.i("$runtimeType initialized<<<<<<<<<<<<");
  }

  void createCacheAndService();

  @mustCallSuper
  Future<void> close() async {
    _closeService();
    await _closeLocalCache();
  }

  Future<void> _closeLocalCache() async {
    await _cache?.close();
    _cache = null;
  }

  void _closeService() {
    _service?.close();
    _service = null;
  }
}
