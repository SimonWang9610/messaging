// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class SyncPoint {
  final String chatId;
  final String msgId;
  final int lastSync;
  final int lastModified;
  SyncPoint({
    required this.chatId,
    required this.msgId,
    required this.lastSync,
    required this.lastModified,
  });

  SyncPoint copyWith({
    String? chatId,
    String? msgId,
    int? lastSync,
    int? lastModified,
  }) {
    return SyncPoint(
      chatId: chatId ?? this.chatId,
      msgId: msgId ?? this.msgId,
      lastSync: lastSync ?? this.lastSync,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  SyncPoint compare(SyncPoint? other) {
    if (other == null) return this;
    return lastModified > other.lastModified ? this : other;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'chatId': chatId,
      'msgId': msgId,
      'lastSync': lastSync,
      'lastModified': lastModified,
    };
  }

  factory SyncPoint.fromMap(Map<String, dynamic> map) {
    return SyncPoint(
      chatId: map['chatId'] as String,
      msgId: map['msgId'] as String,
      lastSync: map['lastSync'] as int,
      lastModified: map['lastModified'] as int,
    );
  }

  String toJson() => json.encode(toMap());

  factory SyncPoint.fromJson(String source) =>
      SyncPoint.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'SyncPoint(chatId: $chatId, msgId: $msgId, lastSync: $lastSync, lastModified: $lastModified)';
  }

  @override
  bool operator ==(covariant SyncPoint other) {
    if (identical(this, other)) return true;

    return other.chatId == chatId &&
        other.msgId == msgId &&
        other.lastSync == lastSync &&
        other.lastModified == lastModified;
  }

  @override
  int get hashCode {
    return chatId.hashCode ^
        msgId.hashCode ^
        lastSync.hashCode ^
        lastModified.hashCode;
  }
}
