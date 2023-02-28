import 'dart:math';

enum ContactStatus {
  /// 1: the server has sent the invitation to the user
  pending(0),

  /// 2: the invitation is accepted by the user
  accepted(1),

  /// 3: this contact is block by you
  block(2),

  /// 4: this contact is in your blacklist
  blacklist(3),

  deleted(4),

  /// -1: this invitation is rejected
  /// once the contact status is rejected, the local and remote database would not have any information about it
  reject(-1);

  final int value;
  const ContactStatus(this.value);

  static ContactStatus fromInt(int value) {
    switch (value) {
      case 0:
        return pending;
      case 1:
        return accepted;
      case 2:
        return block;
      case 3:
        return blacklist;
      case 4:
        return deleted;
      case -1:
        return reject;
      default:
        throw UnsupportedError(
            "mapping $value to [ContactStatus] not supported");
    }
  }

  static ContactStatus merge(ContactStatus a, ContactStatus b) {
    final minStatus = min(a.value, b.value);

    if (minStatus == -1) {
      return a.value > b.value ? b : a;
    } else {
      return a.value > b.value ? a : b;
    }
  }
}
