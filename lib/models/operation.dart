enum Operation {
  added(0),
  updated(1),
  deleted(2);

  final int value;
  const Operation(this.value);

  static Operation merge(Operation a, Operation b) {
    return a.value > b.value ? a : b;
  }
}
