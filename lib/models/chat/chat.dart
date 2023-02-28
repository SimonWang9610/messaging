// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:messaging/models/message/message.dart';
import 'package:messaging/models/message/message_cluster.dart';

import 'sync_point.dart';

class Chat {
  /// the document id in firestore
  final String id;
  final int createdOn;
  final int lastModified;
  final List<String> members;
  final List<String> clusters;
  final String membersHash;

  /// local data
  final SyncPoint? syncPoint;
  final Message? lastMessage;
  final int unread;
  Chat({
    required this.id,
    required this.createdOn,
    required this.lastModified,
    required this.members,
    required this.clusters,
    required this.membersHash,
    this.syncPoint,
    this.lastMessage,
    this.unread = 0,
  });

  Chat copyWith({
    String? id,
    int? createdOn,
    int? lastModified,
    List<String>? members,
    List<String>? clusters,
    String? membersHash,
    SyncPoint? syncPoint,
    Message? lastMessage,
    int? unread,
  }) {
    final message =
        lastMessage?.compareCreatedOn(this.lastMessage) ?? this.lastMessage;

    return Chat(
      id: id ?? this.id,
      createdOn: createdOn ?? this.createdOn,
      lastModified: lastModified ?? this.lastModified,
      members: members ?? this.members,
      clusters: clusters ?? this.clusters,
      membersHash: membersHash ?? this.membersHash,
      syncPoint: syncPoint ?? this.syncPoint,
      lastMessage: message,
      unread: unread ?? this.unread,
    );
  }

  MessageCluster get latestCluster =>
      MessageCluster(path: clusters.last, chatId: id);

  Chat merge(Chat? other) {
    if (other == null || id != other.id || membersHash != other.membersHash) {
      return this;
    }

    final needReplace = lastModified < other.lastModified;

    final mergedClusters = !needReplace ? clusters : other.clusters;

    // typically for group chat
    // because members may add/removed
    // so hash should be the later one
    final hash = !needReplace ? membersHash : other.membersHash;

    final message = !needReplace ? lastMessage : other.lastMessage;
    final count = !needReplace ? unread : other.unread;

    return Chat(
      id: id,
      createdOn: createdOn,
      lastModified: max(lastModified, other.lastModified),
      members: members,
      clusters: mergedClusters,
      membersHash: hash,
      lastMessage: message ?? lastMessage ?? other.lastMessage,
      unread: count,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'createdOn': createdOn,
      'lastModified': lastModified,
      'members': members,
      'clusters': clusters,
      'membersHash': membersHash,
      'syncPoint': syncPoint?.toMap(),
      'lastMessage': lastMessage?.toMap(),
      'unread': unread,
    };
  }

  /// firestore never stores [syncPoint], [lastMessage] and [unread]
  factory Chat.fromMap(Map<String, dynamic> map) {
    return Chat(
      id: map['id'] as String,
      createdOn: map['createdOn'] as int,
      lastModified: map['lastModified'] as int,
      members: List<String>.from(map['members']),
      clusters: List<String>.from(map['clusters']),
      membersHash: map['membersHash'] as String,
      // syncPoint: map['syncPoint'] != null
      //     ? SyncPoint.fromMap(map['syncPoint'] as Map<String, dynamic>)
      //     : null,
      // lastMessage: null,
      // unread: 0,
    );
  }

  String toJson() => json.encode(toMap());

  factory Chat.fromJson(String source) =>
      Chat.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'Chat(id: $id, createdOn: $createdOn, lastModified: $lastModified, members: $members, clusters: $clusters, membersHash: $membersHash, syncPoint: $syncPoint, lastMessage: $lastMessage, unread: $unread)';
  }

  @override
  bool operator ==(covariant Chat other) {
    if (identical(this, other)) return true;

    return other.id == id &&
        other.createdOn == createdOn &&
        other.lastModified == lastModified &&
        listEquals(other.members, members) &&
        listEquals(other.clusters, clusters) &&
        other.membersHash == membersHash &&
        other.syncPoint == syncPoint &&
        other.lastMessage == lastMessage &&
        other.unread == unread;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        createdOn.hashCode ^
        lastModified.hashCode ^
        members.hashCode ^
        clusters.hashCode ^
        membersHash.hashCode ^
        syncPoint.hashCode ^
        lastMessage.hashCode ^
        unread.hashCode;
  }
}

class PendingLastMessage {
  int? _lastModified;
  Message? _lastMessage;
  final List<Message> _messages;

  PendingLastMessage({List<Message>? messages}) : _messages = messages ?? [];

  List<Message> get messages => _messages;

  void add(Message lastMessage) {
    _lastMessage = lastMessage.compareCreatedOn(_lastMessage);

    if (_lastModified == null) {
      _lastModified = lastMessage.lastModified;
    } else {
      _lastModified = max(_lastModified!, lastMessage.lastModified);
    }

    final duplicate =
        _messages.lastIndexWhere((msg) => msg.uniqueId == lastMessage.uniqueId);

    if (duplicate > -1) {
      _messages[duplicate] = _messages[duplicate].merge(lastMessage);
    } else {
      _messages.add(lastMessage);
    }
  }

  void merge(PendingLastMessage pending) {
    final mergedMessages = <Message>[];

    _lastMessage = pending.last.compareCreatedOn(_lastMessage);
    _lastModified = max(_lastModified!, pending.lastModified);

    for (final old in _messages) {
      final duplicate = pending.messages
          .lastIndexWhere((msg) => msg.uniqueId == old.uniqueId);

      if (duplicate > -1) {
        final msg = old.merge(pending.messages.removeAt(duplicate));
        mergedMessages.add(msg);
      } else {
        mergedMessages.add(old);
      }
    }

    _messages.clear();
    _messages.addAll([...mergedMessages, ...pending.messages]);
  }

  int countUnread(String currentUser,
      {SyncPoint? syncPoint, bool isSubscribed = false}) {
    int count = 0;

    if (isSubscribed || _messages.isEmpty) {
      return count;
    } else if (syncPoint == null) {
      return _messages.where((msg) => msg.sender != currentUser).length;
    }

    for (final msg in _messages) {
      if (msg.chatId == syncPoint.chatId &&
          msg.createdOn > syncPoint.lastSync &&
          msg.sender != currentUser) {
        count++;
      }
    }
    return count;
  }

  Message get last => _lastMessage!;

  int get lastModified => _lastModified!;
}
