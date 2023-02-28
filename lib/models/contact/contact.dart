// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';
import 'dart:math';

import 'contact_status.dart';

class Contact {
  /// the document ID on firestore
  final String id;

  /// userid
  final String invitee;

  /// the date when this invitation is created
  final int createdOn;

  /// the date when this contact info is modified
  /// initialize same as [createdOn]
  final int lastModified;

  /// the contact status
  /// see [ContactStatus]
  final ContactStatus status;

  /// if this invitation is created by you
  final String inviter;

  Contact({
    required this.id,
    required this.invitee,
    required this.createdOn,
    required this.lastModified,
    required this.status,
    required this.inviter,
  });

  Contact copyWith({
    String? id,
    String? invitee,
    int? createdOn,
    int? lastModified,
    ContactStatus? status,
    String? inviter,
  }) {
    return Contact(
      id: id ?? this.id,
      invitee: invitee ?? this.invitee,
      createdOn: createdOn ?? this.createdOn,
      lastModified: lastModified ?? this.lastModified,
      status: status ?? this.status,
      inviter: inviter ?? this.inviter,
    );
  }

  Contact merge(Contact? other) {
    if (other == null || other.id != id) return this;

    return Contact(
      id: id,
      invitee: invitee,
      createdOn: createdOn,
      lastModified: max(lastModified, other.lastModified),
      status: ContactStatus.merge(status, other.status),
      inviter: inviter,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'invitee': invitee,
      'createdOn': createdOn,
      'lastModified': lastModified,
      'status': status.value,
      'inviter': inviter,
    };
  }

  factory Contact.fromMap(Map<String, dynamic> map) {
    return Contact(
      id: map['id'] as String,
      invitee: map['invitee'] as String,
      createdOn: map['createdOn'] as int,
      lastModified: map['lastModified'] as int,
      status: ContactStatus.fromInt(map['status'] as int),
      inviter: map['inviter'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory Contact.fromJson(String source) =>
      Contact.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'Contact(id: $id, invitee: $invitee, createdOn: $createdOn, lastModified: $lastModified, status: $status, inviter: $inviter)';
  }

  @override
  bool operator ==(covariant Contact other) {
    if (identical(this, other)) return true;

    return other.id == id &&
        other.invitee == invitee &&
        other.createdOn == createdOn &&
        other.lastModified == lastModified &&
        other.status == status &&
        other.inviter == inviter;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        invitee.hashCode ^
        createdOn.hashCode ^
        lastModified.hashCode ^
        status.hashCode ^
        inviter.hashCode;
  }
}
