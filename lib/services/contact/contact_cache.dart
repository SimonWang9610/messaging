import 'dart:math';
import 'package:messaging/models/operation.dart';
import 'package:messaging/utils/utils.dart';

import '../../models/contact/models.dart';
import '../base/base_cache.dart';

// todo: handle [loadLocalCacheData]
class ContactCache extends BaseCache<int, ContactEvent> {
  ContactCache({super.isBroadcast = false});

  final Map<String, Contact> _localContacts = {};

  List<Contact> get sortedContact => List.unmodifiable(
        _localContacts.values.toList()
          ..sort((a, b) => a.lastModified - b.lastModified),
      );

  /// all modifications to [Contact] would be updated in firestore unless a [Contact] is deleted from firestore
  /// therefore, we should set the [ContactStatus.deleted] manually if [Operation.deleted]
  @override
  void dispatchAll(events) {
    int? latterLastModified;

    for (final event in events) {
      final merged = event.contact?.merge(_localContacts[event.contactId]);

      if (merged == null) continue;

      if (event.operation == Operation.deleted) {
        _localContacts.remove(merged.id);
      } else {
        _localContacts[event.contactId] = merged;
      }

      if (latterLastModified == null) {
        latterLastModified = merged.lastModified;
      } else {
        latterLastModified = max(latterLastModified, merged.lastModified);
      }
    }

    CheckPointManager.store(Constants.contactCheckPoint,
        checkPoint: latterLastModified);

    if (!eventEmitter.isClosed) {
      eventEmitter.add(DateTime.now().millisecondsSinceEpoch);
    }
  }

  @override
  void dispatch(event) {}

  @override
  Future<void> init() async {
    await loadLocalCacheData();
  }

  bool isContact(String email) {
    final found = _localContacts.values.where(
      (contact) =>
          contact.invitee == email ||
          contact.inviter == email && contact.status == ContactStatus.accepted,
    );
    return found.isNotEmpty;
  }
}
