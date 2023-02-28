import "dart:async";
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'animated_overlay.dart';

typedef LoaderFutureCompleted<T> = bool Function(T);
typedef FutureCompletedCallback<T> = FutureOr<void> Function(T);
typedef FutureExceptionCallback<T> = FutureOr<void> Function(T);

class Loader extends AnimatedOverlay {
  static final _instance = Loader._();

  Loader._() : super();
  factory Loader() => _instance;

  OverlayEntry? _overlay;
  OverlayEntry? _barrier;

  bool _hasOverlay = false;

  /// if [future] throw exception, loader will be removed and then invoke [onException] if applicable
  /// [onSuccess] will be invoke if [future] returns correctly
  /// [removeOnceFutureComplete] determines if removing loader once [future] returns
  /// if false, loader will be removed after calling [onSuccess]
  /// if true, loader will be removed before calling [onSuccess]
  void loadingIfException<T>(
    BuildContext context, {
    required Future<T> future,
    FutureCompletedCallback<T>? onSuccess,
    FutureExceptionCallback<Exception>? onException,
    WidgetBuilder? loaderIndicator,
    bool removeOnceFutureComplete = false,
  }) {
    _ensureLegallyInvokeVoidCallback(() {
      _insertLoader(context, loaderIndicator ?? _defaultLoaderIndicator);
      _removeIfNoException(
        future: future,
        onSuccess: onSuccess,
        onException: onException,
        removeOnceFutureComplete: removeOnceFutureComplete,
      );
    });
  }

  void _insertLoader(BuildContext context, WidgetBuilder? loaderIndicator) {
    assert(!_hasOverlay,
        "should add loader into a queue when there is another loader on the screen");

    _barrier = createBarrier(onDismiss: hideCurrentLoader);
    _overlay =
        createOverlay(builder: loaderIndicator ?? _defaultLoaderIndicator);

    Overlay.of(context).insertAll([_barrier!, _overlay!]);

    _hasOverlay = true;
  }

  void _removeIfNoException<T>({
    required Future<T> future,
    FutureCompletedCallback<T>? onSuccess,
    FutureExceptionCallback<Exception>? onException,
    bool removeOnceFutureComplete = false,
  }) async {
    try {
      final T result = await future;

      // assert(
      //     result != null, "null future result should be caught as exception");

      if (removeOnceFutureComplete) {
        _removeOverlay();
      }

      if (onSuccess != null) {
        onSuccess(result);
      }

      if (!removeOnceFutureComplete) {
        _removeOverlay();
      }
    } on Exception catch (e) {
      _removeOverlay();

      onException?.call(e);
    }
  }

  /// avoid [setState] and [markNeedsBuild] when a frame is building
  /// only invoke [callback] if:
  ///  1) flutter is in [SchedulerPhase.postFrameCallbacks]. at this time, no build/layout is going
  ///  2) if not, register [callback] as a post frame callback and will be invoked in the next frame
  void _ensureLegallyInvokeVoidCallback(Function callback) {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.postFrameCallbacks) {
      callback();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        callback();
      });
    }
  }

  void hideCurrentLoader() {
    if (!_hasOverlay) return;

    _removeOverlay();
  }

  void _removeOverlay() {
    _overlay?.remove();
    _barrier?.remove();

    _overlay = null;
    _barrier = null;
    _hasOverlay = false;
  }
}

Widget _defaultLoaderIndicator(BuildContext context) =>
    const CircularProgressIndicator();

class DefaultLoaderIndicator extends AnimatedWidget {
  final Animation<double> animation;
  final Curve curve;

  const DefaultLoaderIndicator({
    Key? key,
    required this.animation,
    this.curve = Curves.linearToEaseOut,
  }) : super(key: key, listenable: animation);

  @override
  Widget build(BuildContext context) {
    // final value = curve.transform(animation.value);

    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}
