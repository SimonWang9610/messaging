import 'package:flutter/material.dart';
import '../components/slide_page_builder.dart';
import '../components/overlays/local_dialog.dart';
import '../components/overlays/local_loader.dart';

extension NavigationExt on BuildContext {
  void push({
    required Widget page,
    Offset transitionBegin = const Offset(1, 0),
    Offset transitionEnd = Offset.zero,
  }) {
    Navigator.of(this).push(
      SlidePageBuilder(
        page: page,
        begin: transitionBegin,
        end: transitionEnd,
      ),
    );
  }

  void pop() {
    Navigator.of(this).pop();
  }

  void maybePop() {
    Navigator.of(this).maybePop();
  }

  void pushReplacement({
    required Widget page,
    Offset transitionBegin = const Offset(1, 0),
    Offset transitionEnd = Offset.zero,
  }) {
    Navigator.of(this).pushReplacement(
      SlidePageBuilder(
        page: page,
        begin: transitionBegin,
        end: transitionEnd,
      ),
    );
  }

  void pushAndRemoveUntil({
    required Widget page,
    Offset transitionBegin = const Offset(1, 0),
    Offset transitionEnd = Offset.zero,
  }) {
    Navigator.of(this).pushAndRemoveUntil(
      SlidePageBuilder(
        page: page,
        begin: transitionBegin,
        end: transitionEnd,
      ),
      (route) => false,
    );
  }

  void pushNamed(String routeName, {Object? args}) {
    Navigator.of(this).pushNamed(routeName, arguments: args);
  }

  void pushReplaceNamed(String routeName, {Object? args}) {
    Navigator.of(this).pushReplacementNamed(routeName, arguments: args);
  }

  void pushNamedAndRemoveUntil(
    String routeName, {
    Object? args,
    RoutePredicate? predicate,
  }) {
    Navigator.of(this).pushNamedAndRemoveUntil(
      routeName,
      (route) => predicate?.call(route) ?? false,
      arguments: args,
    );
  }
}

extension DialogExt on BuildContext {
  void showDialog({
    required Widget child,
    Object? id,
    AnimatedOverlayBuilder? animatedBuilder,
    CompositedPosition? position,
    Duration duration = const Duration(milliseconds: 150),
    bool useBarrier = true,
  }) {
    return LocalDialog().push(
      this,
      child: child,
      id: id,
      animatedBuilder: animatedBuilder,
      position: position,
      duration: duration,
      useBarrier: useBarrier,
    );
  }

  void hideDialog() {
    return LocalDialog().pop();
  }

  void showModal({
    required String modalId,
    required Widget child,
    AnimatedOverlayBuilder? animatedBuilder,
    CompositedPosition? position,
    Duration duration = const Duration(milliseconds: 150),
  }) {
    return LocalDialog().pushOrPopModal(
      this,
      modalId: modalId,
      child: child,
      animatedBuilder: animatedBuilder,
      position: position,
      duration: duration,
    );
  }

  bool hideModal(String modalId) {
    return LocalDialog().popModal(modalId);
  }
}

extension LoaderExt on BuildContext {
  void loading<T>({
    required Future<T> future,
    FutureCompletedCallback<T>? onSuccess,
    FutureExceptionCallback<Exception>? onException,
    WidgetBuilder? loaderIndicator,
    bool removeOnceFutureComplete = false,
  }) {
    Loader().loadingIfException<T>(
      this,
      future: future,
      removeOnceFutureComplete: removeOnceFutureComplete,
      loaderIndicator: loaderIndicator,
      onSuccess: onSuccess,
      onException: onException,
    );
  }
}
