// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';
import 'dart:math';

import 'message_status.dart';
import 'message_type.dart';

class Message {
  /// message unique id, also the document id in firestore
  final String id;

  /// the chat it belongs to
  final String chatId;

  /// the date this message is created by the sender
  final int createdOn;

  /// used to listener filter for firestore
  /// ao that the client can detect the changes of [status] on firestore
  final int lastModified;

  /// the message status, see [MessageStatus]
  final MessageStatus status;
  final String sender;

  /// see [MessageType]
  final MessageType type;

  /// the cluster collection in firestore
  final String cluster;

  /// if this message quotes another [Message]
  /// [quoteId] would be the quoted message id
  final String? quoteId;

  final String body;

  const Message({
    required this.id,
    required this.chatId,
    required this.createdOn,
    required this.lastModified,
    required this.status,
    required this.sender,
    required this.type,
    required this.cluster,
    this.quoteId,
    required this.body,
  });

  bool get isPlainText => type == MessageType.text;
  String get uniqueId => "$chatId-$cluster-$id";

  Message copyWith({
    String? id,
    String? chatId,
    int? createdOn,
    int? lastModified,
    MessageStatus? status,
    String? sender,
    MessageType? type,
    String? cluster,
    String? quoteId,
    String? body,
  }) {
    return Message(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      createdOn: createdOn ?? this.createdOn,
      lastModified: lastModified ?? this.lastModified,
      status: status ?? this.status,
      sender: sender ?? this.sender,
      type: type ?? this.type,
      cluster: cluster ?? this.cluster,
      quoteId: quoteId ?? this.quoteId,
      body: body ?? this.body,
    );
  }

  /// only messages that belong to the same cluster and have the same id would be merged;
  /// [statusOverride] typically only happens this message is deleted physically from firestore
  Message merge(Message? other, {MessageStatus? statusOverride}) {
    if (other == null || (other.uniqueId != other.uniqueId)) {
      return copyWith(status: statusOverride);
    }

    final mergedStatus = statusOverride ??
        MessageStatus.fromInt(max(status.value, other.status.value));

    return Message(
      id: id,
      chatId: chatId,
      createdOn: createdOn,
      lastModified: max(lastModified, other.lastModified),
      status: mergedStatus,
      sender: sender,
      type: type,
      cluster: cluster,
      body: body,
      quoteId: quoteId,
    );
  }

  Message compareLastModified(Message? other) {
    if (other == null) return this;

    return lastModified > other.lastModified ? this : other;
  }

  Message compareCreatedOn(Message? other) {
    if (other == null) return this;

    return createdOn > other.createdOn ? this : other;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'chatId': chatId,
      'createdOn': createdOn,
      'lastModified': lastModified,
      'status': status.value,
      'sender': sender,
      'type': type.value,
      'cluster': cluster,
      'quoteId': quoteId,
      'body': body,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String,
      chatId: map['chatId'] as String,
      createdOn: map['createdOn'] as int,
      lastModified: map['lastModified'] as int,
      status: MessageStatus.fromInt(map['status'] as int),
      sender: map['sender'] as String,
      type: MessageType.fromString(map['type']),
      cluster: map['cluster'] as String,
      quoteId: map['quoteId'] != null ? map['quoteId'] as String : null,
      body: map['body'] as String,
    );
  }

  factory Message.fromStatus(Map<String, dynamic> map, MessageStatus status) {
    final body = map["body"] ?? map["text"] ?? map["mediaUrl"];

    return Message(
      id: map['id'] as String,
      chatId: map['chatId'] as String,
      createdOn: map['createdOn'] as int,
      lastModified: map['lastModified'] as int,
      status: status,
      sender: map['sender'] as String,
      type: MessageType.fromString(map['type'] as String),
      cluster: map['cluster'] as String,
      quoteId: map['quoteId'] != null ? map['quoteId'] as String : null,
      body: body as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory Message.fromJson(String source) =>
      Message.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'Message(id: $id, chatId: $chatId, createdOn: $createdOn, lastModified: $lastModified, status: $status, sender: $sender, type: $type, cluster: $cluster, quoteId: $quoteId, body: $body)';
  }

  @override
  bool operator ==(covariant Message other) {
    if (identical(this, other)) return true;

    return other.id == id &&
        other.chatId == chatId &&
        other.createdOn == createdOn &&
        other.lastModified == lastModified &&
        other.status == status &&
        other.sender == sender &&
        other.type == type &&
        other.cluster == cluster &&
        other.quoteId == quoteId &&
        other.body == body;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        chatId.hashCode ^
        createdOn.hashCode ^
        lastModified.hashCode ^
        status.hashCode ^
        sender.hashCode ^
        type.hashCode ^
        cluster.hashCode ^
        quoteId.hashCode ^
        body.hashCode;
  }
}
