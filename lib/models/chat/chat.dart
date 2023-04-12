// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:messaging/models/message/message.dart';
import 'package:messaging/models/message/message_cluster.dart';
import 'package:messaging/models/message/models.dart';

import 'sync_point.dart';

class Chat {
  /// the document id in firestore
  final String docId;
  final int createdOn;
  final int lastModified;
  final List<String> members;
  final String cluster;
  final String membersHash;

  /// local data
  final SyncPoint? syncPoint;
  final Message? lastMessage;
  final int unread;
  Chat({
    required this.docId,
    required this.createdOn,
    required this.lastModified,
    required this.members,
    required this.cluster,
    required this.membersHash,
    this.syncPoint,
    this.lastMessage,
    this.unread = 0,
  });

  Chat copyWith({
    String? docId,
    int? createdOn,
    int? lastModified,
    List<String>? members,
    String? cluster,
    String? membersHash,
    SyncPoint? syncPoint,
    Message? lastMessage,
    int? unread,
  }) {
    return Chat(
      docId: docId ?? this.docId,
      createdOn: createdOn ?? this.createdOn,
      lastModified: lastModified ?? this.lastModified,
      members: members ?? this.members,
      cluster: cluster ?? this.cluster,
      membersHash: membersHash ?? this.membersHash,
      syncPoint: syncPoint ?? this.syncPoint,
      lastMessage: lastMessage ?? this.lastMessage,
      unread: unread ?? this.unread,
    );
  }

  MessageCluster get latestCluster =>
      MessageCluster(path: cluster, chatId: docId);

  Chat merge(Chat? other) {
    if (other == null ||
        docId != other.docId ||
        membersHash != other.membersHash) {
      return this;
    }

    final needReplace = lastModified < other.lastModified;

    // typically for group chat
    // because members may add/removed
    // so hash should be the later one
    final hash = !needReplace ? membersHash : other.membersHash;

    final message = !needReplace ? lastMessage : other.lastMessage;
    final count = !needReplace ? unread : other.unread;

    return Chat(
      docId: docId,
      createdOn: createdOn,
      lastModified: max(lastModified, other.lastModified),
      members: members,
      cluster: cluster,
      membersHash: hash,
      lastMessage: message ?? lastMessage ?? other.lastMessage,
      unread: count,
    );
  }

  // bool shouldSync(Chat? other) {
  //   if (other == null) return true;

  //   return docId != other.docId ||
  //       membersHash != other.membersHash ||
  //       lastModified != other.lastModified ||
  //       syncPoint != other.syncPoint ||
  //       lastMessage != other.lastMessage;
  // }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'docId': docId,
      'createdOn': createdOn,
      'lastModified': lastModified,
      'members': members,
      'cluster': cluster,
      'membersHash': membersHash,
      'syncPoint': syncPoint?.toMap(),
      'lastMessage': lastMessage?.toMap(),
      'unread': unread,
    };
  }

  /// firestore never stores [syncPoint], [lastMessage] and [unread]
  factory Chat.fromMap(Map<String, dynamic> map) {
    return Chat(
      docId: map['docId'] as String,
      createdOn: map['createdOn'] as int,
      lastModified: map['lastModified'] as int,
      members: List<String>.from(map['members']),
      cluster: map['cluster'] as String,
      membersHash: map['membersHash'] as String,
      // syncPoint: map['syncPoint'] != null
      //     ? SyncPoint.fromMap(map['syncPoint'] as Map<String, dynamic>)
      //     : null,
      // lastMessage: map['lastMessage'] != null
      //     ? Message.fromMap(map['lastMessage'] as Map<String, dynamic>)
      //     : null,
      // unread: map['unread'] as int,
    );
  }

  String toJson() => json.encode(toMap());

  factory Chat.fromJson(String source) =>
      Chat.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'Chat(docId: $docId, createdOn: $createdOn, lastModified: $lastModified, members: $members, cluster: $cluster, membersHash: $membersHash, syncPoint: $syncPoint, lastMessage: $lastMessage, unread: $unread)';
  }

  @override
  bool operator ==(covariant Chat other) {
    if (identical(this, other)) return true;

    return other.docId == docId &&
        other.createdOn == createdOn &&
        other.lastModified == lastModified &&
        listEquals(other.members, members) &&
        cluster == other.cluster &&
        other.membersHash == membersHash &&
        other.syncPoint == syncPoint &&
        other.lastMessage == lastMessage &&
        other.unread == unread;
  }

  @override
  int get hashCode {
    return docId.hashCode ^
        createdOn.hashCode ^
        lastModified.hashCode ^
        members.hashCode ^
        cluster.hashCode ^
        membersHash.hashCode ^
        syncPoint.hashCode ^
        lastMessage.hashCode ^
        unread.hashCode;
  }
}
