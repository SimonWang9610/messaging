// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';
import 'dart:math';

import 'friend_status.dart';

class Friend {
  /// both users share the same docId if they are [Friend]
  /// it is calculated by [generateFriendDocId]
  /// particularly, if their [Chat] is one-to-one, the chat's membersHash would be equal to [docId]
  final String docId;

  /// not change once determined
  final String userId;

  /// may change
  final String username;

  /// may change
  final String email;
  final int createdOn;
  final int lastModified;

  /// see [FriendStatus]
  final FriendStatus status;

  /// this field is nto stored on firestore
  /// but it would be stored at the local database
  /// because one device may have multiple users logged in
  /// we must distinguish which [Friend] records belong to the current user
  // final String belongTo;

  /// who send the invitation
  /// not change once determined
  final String createdBy;

  /// the nickname for [belongTo] friend
  /// both users may set different nicknames for another person
  /// such changes would only be written into [belongTo]'s local database and firestore
  final String? nickname;

  Friend({
    required this.docId,
    required this.userId,
    required this.username,
    required this.email,
    required this.createdOn,
    required this.lastModified,
    required this.status,
    // required this.belongTo,
    required this.createdBy,
    this.nickname,
  });

  Friend copyWith({
    String? docId,
    String? userId,
    String? username,
    String? email,
    int? createdOn,
    int? lastModified,
    FriendStatus? status,
    String? belongTo,
    String? createdBy,
    String? nickname,
  }) {
    return Friend(
      docId: docId ?? this.docId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      email: email ?? this.email,
      createdOn: createdOn ?? this.createdOn,
      lastModified: lastModified ?? this.lastModified,
      status: status ?? this.status,
      // belongTo: belongTo ?? this.belongTo,
      createdBy: createdBy ?? this.createdBy,
      nickname: nickname ?? this.nickname,
    );
  }

  /// typically happens when:
  /// 1) friends change their [email]/[username]
  /// 2) [status] change
  /// 3) the current user sets a new nickname for friends
  Friend merge(Friend? other) {
    if (other == null || docId != other.docId) {
      return this;
    }

    final needReplace = lastModified < other.lastModified;

    return Friend(
      userId: userId,
      docId: docId,
      createdBy: createdBy,
      email: needReplace ? other.email : email,
      username: needReplace ? other.username : username,
      createdOn: createdOn,
      lastModified: max(lastModified, other.lastModified),
      status: needReplace ? other.status : status,
      nickname: needReplace ? other.nickname : nickname,
      // belongTo: belongTo,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'docId': docId,
      'userId': userId,
      'username': username,
      'email': email,
      'createdOn': createdOn,
      'lastModified': lastModified,
      'status': status.value,
      // 'belongTo': belongTo,
      'createdBy': createdBy,
      'nickname': nickname,
    };
  }

  factory Friend.fromMap(Map<String, dynamic> map) {
    return Friend(
      docId: map['docId'] as String,
      userId: map['userId'] as String,
      username: map['username'] as String,
      email: map['email'] as String,
      createdOn: map['createdOn'] as int,
      lastModified: map['lastModified'] as int,
      status: FriendStatus.fromInt(map['status'] as int),
      // belongTo: map['belongTo'] as String,
      createdBy: map['createdBy'] as String,
      nickname: map['nickname'] != null ? map['nickname'] as String : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory Friend.fromJson(String source) =>
      Friend.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'Friend(docId: $docId, userId: $userId, username: $username, email: $email, createdOn: $createdOn, lastModified: $lastModified, status: $status, createdBy: $createdBy, nickname: $nickname)';
  }

  @override
  bool operator ==(covariant Friend other) {
    if (identical(this, other)) return true;

    return other.docId == docId &&
        other.userId == userId &&
        other.username == username &&
        other.email == email &&
        other.createdOn == createdOn &&
        other.lastModified == lastModified &&
        other.status == status &&
        other.createdBy == createdBy &&
        other.nickname == nickname;
  }

  @override
  int get hashCode {
    return docId.hashCode ^
        userId.hashCode ^
        username.hashCode ^
        email.hashCode ^
        createdOn.hashCode ^
        lastModified.hashCode ^
        status.hashCode ^
        createdBy.hashCode ^
        nickname.hashCode;
  }
}
