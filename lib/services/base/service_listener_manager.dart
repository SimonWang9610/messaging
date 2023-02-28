import 'dart:async';

mixin RemoteServiceListenerManager {
  final Map<String, StreamSubscription> _listeners = {};

  void cancelAllListeners() {
    if (_listeners.isNotEmpty) {
      for (final listener in _listeners.values) {
        listener.cancel();
      }
    }
  }

  void addListener(String key, StreamSubscription sub) {
    _listeners[key]?.cancel();
    _listeners[key] = sub;
  }

  void removeListener(String key) {
    _listeners[key]?.cancel();
    _listeners.remove(key);
  }

  bool hasListenerFor(String key) {
    return _listeners.containsKey(key);
  }
}
