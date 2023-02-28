import "package:flutter/material.dart";
import "animated_overlay.dart";

class OverlayPair {
  final Object? id;
  final OverlayEntry? barrier;
  final OverlayEntry overlay;
  final AnimationController? animation;

  OverlayPair(
    this.overlay, {
    this.id,
    this.barrier,
    this.animation,
  });

  void remove() async {
    await animation?.reverse();
    overlay.remove();
    barrier?.remove();
    animation?.dispose();
  }

  void show(BuildContext context) {
    final overlays = [overlay];

    if (barrier != null) {
      overlays.insert(0, barrier!);
    }

    Overlay.of(context).insertAll(overlays);
    animation?.forward(from: 0);
  }
}

typedef AnimatedOverlayBuilder = Widget Function(Animation<double>, Widget?);

class CompositedPosition {
  final Alignment targetAnchor;
  final Alignment followedAnchor;
  final Offset spacing;
  final LayerLink link;
  final bool showWhenScroll;
  CompositedPosition(
    this.link, {
    this.targetAnchor = Alignment.topLeft,
    this.followedAnchor = Alignment.topLeft,
    this.spacing = Offset.zero,
    this.showWhenScroll = false,
  });
}

class LocalDialog extends AnimatedOverlay {
  static final _instance = LocalDialog._();

  LocalDialog._();
  factory LocalDialog() => _instance;

  final List<OverlayPair> _onstageDialogs = [];
  final Map<String, OverlayPair> _onstageModals = {};

  void push(
    BuildContext context, {
    required Widget child,
    Object? id,
    AnimatedOverlayBuilder? animatedBuilder,
    CompositedPosition? position,
    Duration duration = const Duration(milliseconds: 150),
    bool useBarrier = false,
  }) {
    final overlays = _createOverlays(
      child: child,
      animatedBuilder: animatedBuilder,
      position: position,
      duration: duration,
      useBarrier: useBarrier,
    );

    _onstageDialogs.add(overlays);
    _onstageDialogs.last.show(context);
  }

  /// if [modalId] has been onstage, this push operation will actually pop [modalId]
  /// otherwise, push [modalId]
  void pushOrPopModal(
    BuildContext context, {
    required String modalId,
    required Widget child,
    AnimatedOverlayBuilder? animatedBuilder,
    CompositedPosition? position,
    Duration duration = const Duration(milliseconds: 150),
  }) {
    if (canPopModal(modalId)) {
      popModal(modalId);
      return;
    }

    final overlays = _createOverlays(
      child: child,
      animatedBuilder: animatedBuilder,
      position: position,
      duration: duration,
    );
    _onstageModals.putIfAbsent(modalId, () => overlays);
    overlays.show(context);
  }

  /// pop dialogs
  void pop() {
    final pair = _onstageDialogs.removeLast();
    pair.remove();
  }

  void popUntil({required String until}) {
    if (_onstageDialogs.isNotEmpty) {
      final untilDialog =
          _onstageDialogs.lastIndexWhere((element) => element.id == until);

      if (untilDialog > -1 && untilDialog < _onstageDialogs.length) {
        final willPoppedDialogs = _onstageDialogs.sublist(untilDialog + 1);

        for (final dialog in willPoppedDialogs) {
          final removed = _onstageDialogs.remove(dialog);

          if (removed) {
            dialog.remove();
          }
        }
      }
    }
  }

  /// try pop dialogs
  void mapPop() {
    if (_onstageDialogs.isNotEmpty) {
      pop();
    }
  }

  bool canPopModal(String modalId) => _onstageModals.containsKey(modalId);

  bool popModal(String modalId) {
    final modal = _onstageModals.remove(modalId);
    if (modal != null) {
      modal.remove();
      return true;
    }
    return false;
  }

  void clearModal() {
    if (_onstageModals.isEmpty) return;

    for (final modal in _onstageModals.values) {
      modal.remove();
    }
    _onstageModals.clear();
  }

  /// clear all dialogs
  void clear() {
    if (_onstageDialogs.isEmpty) return;

    for (final dialog in _onstageDialogs) {
      dialog.remove();
    }
    _onstageDialogs.clear();
  }

  /// create [OverlayPair]
  /// [child] the widget is displayed after animation ends
  /// [animatedBuilder] if not null, will wrap [child] by [animatedBuilder]
  /// [useBarrier] if true, will insert a [ModalBarrier] below the [child]
  ///! [barrierDismissible] not stable, avoid using it
  OverlayPair _createOverlays({
    required Widget child,
    AnimatedOverlayBuilder? animatedBuilder,
    CompositedPosition? position,
    Duration duration = const Duration(milliseconds: 150),
    bool useBarrier = false,
    bool barrierDismissible = false,
  }) {
    OverlayEntry? barrier;

    if (useBarrier) {
      barrier = createBarrier(
        dismissible: barrierDismissible,
      );
    }

    Widget result = child;
    AnimationController? animation;

    if (animatedBuilder != null) {
      animation = createController(duration);
      result = animatedBuilder.call(animation, result);
    }

    if (position != null) {
      result = CompositedTransformFollower(
        link: position.link,
        targetAnchor: position.targetAnchor,
        followerAnchor: position.followedAnchor,
        offset: position.spacing,
        showWhenUnlinked: position.showWhenScroll,
        child: result,
      );
    }

    final overlay = OverlayEntry(
      builder: (_) => DefaultTextStyle(
        style: const TextStyle(
          fontSize: 20,
        ),
        textAlign: TextAlign.center,
        child: Align(
          child: result,
        ),
      ),
    );

    return OverlayPair(
      overlay,
      barrier: barrier,
      animation: animation,
    );
  }
}
