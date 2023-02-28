import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/contact/models.dart';
import '../../models/user.dart';
import '../base/base_service.dart';

import '../database.dart';
import '../base/service_error.dart';
import '../service_helper.dart';

import 'contact_cache.dart';

mixin ContactServiceApi on BaseService<ContactCache> {
  RemoteCollection get contacts;

  /// apply to add [user] as your [Contact]
  void invite(User user) async {
    try {
      final newDoc = contacts.doc();

      final contact = user.toContactMap(cache.getCurrentUserEmail(), newDoc.id);

      await newDoc.set(contact);
    } catch (e) {
      throwContactServiceError(e);
    }
  }

  /// update [ContactStatus] for
  /// 1) accept/reject a contact invitation
  /// 2) block/blacklist a contact invitation (waiting improvements)
  void updateStatus(Contact contact, ContactStatus targetStatus) async {
    // todo: should disable updating some fields
    // todo: permission check

    _debugCheckStatusUpdate(contact, targetStatus);

    final updates = <String, dynamic>{
      "lastModified": DateTime.now().millisecondsSinceEpoch,
      "status": targetStatus.value,
    };

    try {
      // final docRef = contacts.doc(contactId);
      // await docRef.update(updates);

      final docRef = await findUniqueDocRef(contacts, "id", contact.id);

      if (docRef != null) {
        await docRef.update(updates);
      } else {
        throw ServiceError(
          type: ServiceErrorType.contact,
          message: "$contact document not exist",
        );
      }
    } catch (e) {
      throwContactServiceError(e);
    }
  }

  void _debugCheckStatusUpdate(Contact contact, ContactStatus targetStatus) {
    final validUpdate =
        (contact.status.value - targetStatus.value).abs() == 1 ||
            (contact.status == ContactStatus.blacklist &&
                (targetStatus == ContactStatus.accepted ||
                    targetStatus == ContactStatus.reject));
    assert(
        validUpdate, "Updating [ContactStatus] must follow some restrictions");
  }
}

mixin UserSearchApi {
  Future<User?> findByUserId(String userid) async {
    try {
      final users = Database.remote.collection("users");

      final docRef = await findUniqueDocRef(users, "id", userid);

      if (docRef != null) {
        final data = await docRef.get().then((snapshot) => snapshot.data()!);
        return User.fromMap(data);
      } else {}
    } catch (e) {
      throwContactServiceError(e);
    }
    return null;
  }

  Future<User?> findByUserEmail(String email) async {
    try {
      final users = Database.remote.collection("users");
      final query = users
          .where(
            "email",
            isEqualTo: email,
          )
          .limit(1);

      final docSnapshot = await query.get();

      if (docSnapshot.size < 1) {
        return null;
      } else {
        final map = docSnapshot.docs.first.data();
        return User.fromMap(map);
      }
    } catch (e) {
      throwContactServiceError(e);
    }
    return null;
  }

  Future<User?> addUser(String email) async {
    try {
      final users = Database.remote.collection("users");

      var docRef = await findUniqueDocRef(users, "email", email);

      if (docRef == null) {
        docRef = users.doc();

        await docRef.set(
          {
            "email": email,
            "id": docRef.id,
          },
          SetOptions(merge: true),
        );
      }

      final map = await docRef.get().then((snapshot) => snapshot.data()!);

      return User.fromMap(map);
    } catch (e) {
      throwContactServiceError(e);
    }
    return null;
  }
}

extension ContactBuilder on User {
  Map<String, dynamic> toContactMap(String inviterEmail, String docId) {
    final createdOn = DateTime.now().millisecondsSinceEpoch;

    return {
      "id": docId,
      "invitee": email,
      "createdOn": createdOn,
      "lastModified": createdOn,
      "status": ContactStatus.pending.value,
      "inviter": inviterEmail,
    };
  }
}
