enum ServiceErrorType {
  contact,
  chat,
  message,
}

class ServiceError implements Exception {
  final String message;
  final ServiceErrorType type;

  const ServiceError({
    required this.type,
    required this.message,
  });

  @override
  String toString() {
    return "ServiceError(type: $type, message: $message)";
  }
}
