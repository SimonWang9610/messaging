import 'dart:async';
import 'package:flutter/widgets.dart';

class AppLifecycleCallback {
  final VoidCallback callback;
  final Duration duration;
  final bool repeated;

  /// if true, [callback] will be invoked once instantly when creating [task]
  final bool runOnCreated;
  const AppLifecycleCallback(
    this.callback, {
    required this.duration,
    this.repeated = false,
    this.runOnCreated = false,
  });

  /// [task] would only be created when no need [repeated] and not [runOnCreated]
  Timer? get task {
    if (repeated) {
      return Timer.periodic(
        duration,
        (_) => callback(),
      );
    } else if (!repeated && !runOnCreated) {
      return Timer(duration, callback);
    } else {
      return null;
    }
  }
}

/// [State] should with [WidgetsBindingObserver] if want to mixin [AppLifecycleObserver]
/// by default, [initState] will not invoke [createTask]
/// so the state should override [initState] if wants to create a task during [initState]
/// By overriding [didChangeAppLifecycleState], the state can do other thing instead of using the default implementation
mixin AppLifecycleObserver<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver {
  Timer? _task;

  Timer? get task => _task;

  AppLifecycleCallback? createAppLifecycleCallback() => null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(state) {
    switch (state) {
      case AppLifecycleState.resumed:
        return createTask();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.paused:
        return cancelTask();
    }
  }

  @override
  void dispose() {
    cancelTask();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void createTask([AppLifecycleCallback? appLifecycleCallback]) {
    cancelTask();
    final callback = appLifecycleCallback ?? createAppLifecycleCallback();

    if (callback != null && callback.runOnCreated) {
      callback.callback();
    }

    _task = callback?.task;
  }

  void cancelTask() {
    _task?.cancel();
    _task = null;
  }
}
