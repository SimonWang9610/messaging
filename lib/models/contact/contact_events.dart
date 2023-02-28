import 'contact.dart';
import '../operation.dart';

class ContactEvent {
  final Operation operation;
  final String contactId;
  final Contact? contact;
  ContactEvent({
    required this.operation,
    required this.contactId,
    this.contact,
  });

  ContactEvent copyWith({
    Operation? operation,
    Contact? contact,
    String? contactId,
  }) {
    return ContactEvent(
      operation: operation ?? this.operation,
      contactId: contactId ?? this.contactId,
      contact: contact ?? this.contact,
    );
  }
}
