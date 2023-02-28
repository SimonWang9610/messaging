import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

typedef AnimatedOverlayBuilder = Widget Function(
    BuildContext, Animation<double>?);

abstract class AnimatedOverlay implements TickerProvider {
  AnimatedOverlay() : super();

  @override
  Ticker createTicker(onTick) => Ticker(onTick);

  AnimationController createController(Duration duration) {
    return AnimationController(vsync: this, duration: duration);
  }

  OverlayEntry createOverlay({required WidgetBuilder builder}) {
    return OverlayEntry(
      builder: (BuildContext context) => Center(
        child: builder(context),
      ),
    );
  }

  OverlayEntry createBarrier({
    Color barrierColor = Colors.black38,
    bool dismissible = false,
    VoidCallback? onDismiss,
  }) {
    return OverlayEntry(
      builder: (BuildContext context) => ModalBarrier(
        color: Colors.black38,
        dismissible: dismissible,
        onDismiss: onDismiss,
      ),
    );
  }
}
