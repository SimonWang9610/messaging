// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class User {
  /// the document id in firestore
  final String id;
  final String email;
  final String? avatar;
  User({
    required this.id,
    required this.email,
    this.avatar,
  });

  User copyWith({
    String? id,
    String? email,
    String? avatar,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'email': email,
      'avatar': avatar,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String,
      email: map['email'] as String,
      avatar: map['avatar'] != null ? map['avatar'] as String : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory User.fromJson(String source) =>
      User.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() => 'User(id: $id, email: $email, avatar: $avatar)';

  @override
  bool operator ==(covariant User other) {
    if (identical(this, other)) return true;

    return other.id == id && other.email == email && other.avatar == avatar;
  }

  @override
  int get hashCode => id.hashCode ^ email.hashCode ^ avatar.hashCode;
}
