import 'package:flutter/material.dart';

class SlidePageBuilder extends PageRouteBuilder {
  final Widget page;
  final Offset begin;
  final Offset end;

  SlidePageBuilder({
    required this.page,
    super.settings,
    this.begin = const Offset(1, 0),
    this.end = Offset.zero,
  }) : super(
          pageBuilder: (_, __, ___) => page,
          transitionsBuilder: (_, animation, __, chid) {
            final tween =
                Tween<Offset>(begin: begin, end: end).animate(animation);

            return SlideTransition(
              position: tween,
              child: chid,
            );
          },
        );
}

class FadePageBuilder extends PageRouteBuilder {
  final Widget page;

  FadePageBuilder({
    required this.page,
    super.settings,
  }) : super(
          pageBuilder: (_, __, ___) => FutureBuilder<Widget>(
            initialData: const Center(
              child: CircularProgressIndicator(),
            ),
            future: Future.microtask(
              () => page,
            ),
            builder: (_, snapshot) {
              if (snapshot.hasData) {
                return snapshot.data!;
              } else {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
            },
          ),
          transitionsBuilder: (_, animation, __, chid) {
            return FadeTransition(
              opacity: animation,
              child: chid,
            );
          },
        );
}
