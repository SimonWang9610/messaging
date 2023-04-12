import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:messaging/models/chat/models.dart';
import 'package:messaging/utils/utils.dart';

import '../models/operation.dart';
import 'base/service_error.dart';

/// since [collections.doc(docId)] would created a new document using the given [docId] if no [docId] is founded
/// by using this method to find a unique document reference
Future<DocumentReference<T>?> findUniqueDocRef<T extends Object>(
    CollectionReference<T> collection, String field, Object value) async {
  final query = collection.where(field, isEqualTo: value).limit(1);

  final snapshot = await query.get();
  if (snapshot.size > 0) {
    return snapshot.docs.first.reference;
  }
  return null;
}

void throwContactServiceError(Object e) {
  if (e is ServiceError) {
    throw e;
  } else {
    throw ServiceError(type: ServiceErrorType.contact, message: "$e");
  }
}

List<String> sortChatMembers(List<String> members) {
  members.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return members;
}

/// the cluster id would have the format: prefix-<type>-<count>
/// [type] indicates the purpose of the cluster
/// [count] indicates the i-th cluster for this [type]
String createClusterId(String prefix,
    {required ClusterType type, required int count}) {
  return "$prefix-${type.value}-$count";
}

/// when creating a [Chat]
/// hashing the sorted members list could simplify and improve the query of which [Chat] have the same members
String hashMembers(List<String> sortedMembers) {
  final key = utf8.encode("firestore");
  final encoded = utf8.encode(sortedMembers.join(","));
  final hmac = Hmac(sha256, key);
  return hmac.convert(encoded).toString();
}

String generateFriendDocId(String selfId, String otherId) {
  return hashMembers(sortChatMembers([selfId, otherId]));
}

Operation mapToOperation(DocumentChangeType type) {
  switch (type) {
    case DocumentChangeType.added:
      return Operation.added;
    case DocumentChangeType.modified:
      return Operation.updated;
    case DocumentChangeType.removed:
      return Operation.deleted;
  }
}

const _clusterCount = 4;

int hashChatIdForCollection(String chatDocId) {
  final encoded = utf8.encode(chatDocId);

  final hash = sha256.convert(encoded).bytes;

  final total =
      hash.fold(0, (previousValue, element) => previousValue + element);

  return total % _clusterCount;
}

String getMessageCollectionPath(String clusterPath) {
  return "${Collection.messageClusters}/$clusterPath/${Collection.message}";
}
