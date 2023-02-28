// File generated by FlutterFire CLI.
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAAqX7UJat56q9C7fzhhH9NYOm9ve4ZdlY',
    appId: '1:610144383960:web:87bf55cfaa739fc5b178ad',
    messagingSenderId: '610144383960',
    projectId: 'simonwang-messaging',
    authDomain: 'simonwang-messaging.firebaseapp.com',
    storageBucket: 'simonwang-messaging.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCW6fEHhVd2kRAHLhuc5tMcHbdpk0RIw4g',
    appId: '1:610144383960:android:2e58e3c545c87165b178ad',
    messagingSenderId: '610144383960',
    projectId: 'simonwang-messaging',
    storageBucket: 'simonwang-messaging.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCZfW8Asj3d25JobdnfK_RTzPZTG5PtqhA',
    appId: '1:610144383960:ios:da8c449e1d5a03aab178ad',
    messagingSenderId: '610144383960',
    projectId: 'simonwang-messaging',
    storageBucket: 'simonwang-messaging.appspot.com',
    iosClientId: '610144383960-ao2bnfqaihlrlt8o34pgkbft41f8q9in.apps.googleusercontent.com',
    iosBundleId: 'com.example.messaging',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCZfW8Asj3d25JobdnfK_RTzPZTG5PtqhA',
    appId: '1:610144383960:ios:da8c449e1d5a03aab178ad',
    messagingSenderId: '610144383960',
    projectId: 'simonwang-messaging',
    storageBucket: 'simonwang-messaging.appspot.com',
    iosClientId: '610144383960-ao2bnfqaihlrlt8o34pgkbft41f8q9in.apps.googleusercontent.com',
    iosBundleId: 'com.example.messaging',
  );
}
