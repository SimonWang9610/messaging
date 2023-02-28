import 'package:logger/logger.dart';

// TODO: close logger when app is inactive
// TODO: send crashlytics when error log occurs using [firebase_crashlytics: ^3.0.9]
// see firebase_crashlytics usage: https://firebase.flutter.dev/docs/crashlytics/usage
class Log {
  static final _logger = Logger();

  static d(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error, stackTrace);
  }

  static i(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error, stackTrace);
  }

  static w(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error, stackTrace);
  }

  static e(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error, stackTrace);
  }

  static close() => _logger.close();
}
