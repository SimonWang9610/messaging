import 'package:flutter/foundation.dart';

@immutable
class CheckPoint {
  final String id;
  final int value;

  const CheckPoint(this.id, this.value);

  @override
  String toString() {
    return 'CheckPoint(id: $id, value: $value)';
  }
}
