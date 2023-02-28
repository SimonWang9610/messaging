import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:messaging/utils/constants.dart';

import '../../models/contact/models.dart';
import '../base/base_service.dart';
import '../base/base_cache.dart';

import '../database.dart';
import '../service_helper.dart';

import 'contact_cache.dart';
import 'contact_service_api.dart';

/// only need to listen to changes that are related to [currentUserEmail]
/// [ContactService] is used to interact with firestore
/// [_listenContactChange] would register listeners that listen to the changes of contact documents related to [currentUserEmail]
/// [_handleContactChange] would dispatch [ContactEvent] using [eventEmitter] according to [DocumentChange.type]
class ContactService extends BaseService<ContactCache>
    with ContactServiceApi, UserSearchApi {
  static const inviter = "inviter";
  static const invitee = "invitee";

  @override
  RemoteCollection get contacts =>
      Database.remote.collection(Collection.contact);

  ContactService(super.cache);

  @override
  Future<void> initListeners() async {
    _listenContactChange(inviter, _handleContactChange);
    _listenContactChange(invitee, _handleContactChange);
  }

  /// by using compound query filters, we could avoid load documents changes that have been loaded by the current device
  /// for example, we could first query the greatest 'lastModified' field for all local contacts
  /// then, we ensure all documents changes whose 'lastModified' is always greater than the above number
  /// but we must created a IndexField by using such compound query filters
  void _listenContactChange(String field, CollectionChangeHandler handler) {
    final current = CheckPointManager.get(Constants.contactCheckPoint);

    var query = contacts.where(
      field,
      isEqualTo: cache.getCurrentUserEmail(),
    );

    // if (current != null) {
    //   query = query.where(
    //     "lastModified",
    //     isGreaterThan: current,
    //   );
    // }

    final sub = query.snapshots().listen(
          handler,
          onError: cache.dispatchError,
          onDone: () => removeListener(field),
        );

    addListener(field, sub);
  }

  /// if the current device is a new device for teh same user, just display the first snapshot
  /// if the current device has registered (that loaded all history contact-related events),
  /// the first snapshot should be ignored, and the history contacts should be loaded from the local database
  void _handleContactChange(QueryChange snapshot) {
    /// the first snapshot always returns all documents as added snapshots
    ///
    final events = <ContactEvent>[];
    for (final change in snapshot.docChanges) {
      final operation = mapToOperation(change.type);

      final map = change.doc.data();
      print(
          "${map?["id"]}, old: ${change.oldIndex}, new: ${change.newIndex}, type: ${change.type}");

      events.add(
        ContactEvent(
          operation: operation,
          contactId: change.doc.id,
          contact: map != null ? Contact.fromMap(map) : null,
        ),
      );
    }
    cache.dispatchAll(events);
  }
}
