// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import '../operation.dart';
import 'friend.dart';

class FriendEvent {
  final Operation operation;
  final String docId;
  final Friend friend;
  FriendEvent({
    required this.operation,
    required this.docId,
    required this.friend,
  });

  FriendEvent copyWith({
    Operation? operation,
    String? docId,
    Friend? friend,
  }) {
    return FriendEvent(
      operation: operation ?? this.operation,
      docId: docId ?? this.docId,
      friend: friend ?? this.friend,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'operation': operation.value,
      'docId': docId,
      'friend': friend.toMap(),
    };
  }

  @override
  String toString() =>
      'FriendEvent(operation: $operation, docId: $docId, friend: $friend)';

  @override
  bool operator ==(covariant FriendEvent other) {
    if (identical(this, other)) return true;

    return other.operation == operation &&
        other.docId == docId &&
        other.friend == friend;
  }
}
