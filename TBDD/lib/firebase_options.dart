import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
            'DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAJJlDWjIFytzR_UFCjxFAMvTvPVodY_Q8',
    appId: '1:673742064314:android:bd42f429bb00169db3d083',
    messagingSenderId: '673742064314',
    projectId: 'tbdd-8af55',
    storageBucket: 'tbdd-8af55.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCYvCWyKS4rQJmWvKgnWgDPo86gVabXD2Q',
    appId: '1:673742064314:ios:111702a121b9116cb3d083',
    messagingSenderId: '673742064314',
    projectId: 'tbdd-8af55',
    storageBucket: 'tbdd-8af55.firebasestorage.app',
    iosBundleId: 'com.example.tbdd',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBGttKc7Wu7rzsh-vwj6HOONfXQNvtkYgs',
    appId: '1:673742064314:web:9f81a0c667186fd7b3d083',
    messagingSenderId: '673742064314',
    projectId: 'tbdd-8af55',
    authDomain: 'tbdd-8af55.firebaseapp.com',
    storageBucket: 'tbdd-8af55.firebasestorage.app',
    measurementId: 'G-BWQEMLCLEY',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBGttKc7Wu7rzsh-vwj6HOONfXQNvtkYgs',
    appId: '1:673742064314:web:8c82e59e0ddc67f4b3d083',
    messagingSenderId: '673742064314',
    projectId: 'tbdd-8af55',
    authDomain: 'tbdd-8af55.firebaseapp.com',
    storageBucket: 'tbdd-8af55.firebasestorage.app',
    measurementId: 'G-JPHL4HQX9W',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCYvCWyKS4rQJmWvKgnWgDPo86gVabXD2Q',
    appId: '1:673742064314:ios:111702a121b9116cb3d083',
    messagingSenderId: '673742064314',
    projectId: 'tbdd-8af55',
    storageBucket: 'tbdd-8af55.firebasestorage.app',
    iosBundleId: 'com.example.tbdd',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'your-linux-api-key',
    appId: 'your-linux-app-id',
    messagingSenderId: 'your-messaging-sender-id',
    projectId: 'your-project-id',
    storageBucket: 'your-storage-bucket',
  );
}