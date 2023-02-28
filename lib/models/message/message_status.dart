enum MessageStatus {
  sending(0),

  /// this message has been sent by the server
  /// but the receiver has not loaded this message
  sent(1),

  /// this message is read by the receiver
  read(2),

  /// this message is deleted by the sender
  deleted(3),

  /// this message fails to be sent by the server
  failed(-1);

  final int value;
  const MessageStatus(this.value);

  static MessageStatus fromInt(int value) {
    switch (value) {
      case 0:
        return sending;
      case 1:
        return sent;
      case 2:
        return read;
      case 3:
        return deleted;
      case -1:
        return failed;
      default:
        throw UnsupportedError(
            "mapping $value to [MessageStatus] not supported");
    }
  }
}
