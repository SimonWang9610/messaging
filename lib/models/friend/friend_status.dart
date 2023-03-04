enum FriendStatus {
  rejected(-1),
  pending(0),
  accepted(1),
  blocked(2),
  blacklist(3),
  deleted(4);

  final int value;
  const FriendStatus(this.value);

  static FriendStatus fromInt(int value) {
    switch (value) {
      case 0:
        return pending;
      case 1:
        return accepted;
      case 2:
        return blocked;
      case 3:
        return blacklist;
      case 4:
        return deleted;
      case 5:
        return rejected;
      default:
        throw UnsupportedError("$value not supported for [FriendStatus]");
    }
  }
}
