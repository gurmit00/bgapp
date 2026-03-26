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
        throw UnsupportedError(
          'DefaultFirebaseOptions has not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions has not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions has not been configured for ${defaultTargetPlatform.name} - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD8ssivcECPRXUFj2_bFQC4lCAIBlC9YTs',
    appId: '1:111416353624:web:03f60ec216d83daa7cfb2d',
    messagingSenderId: '111416353624',
    projectId: 'storeordering-10125',
    authDomain: 'storeordering-10125.firebaseapp.com',
    storageBucket: 'storeordering-10125.firebasestorage.app',
    measurementId: 'G-Z3Y18888WN',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB7eD5X6kL9mN2pO3qR4sT5uV6wX7yZ8aB',
    appId: '1:111416353624:android:a1b2c3d4e5f6g7h8i9j0k1',
    messagingSenderId: '111416353624',
    projectId: 'storeordering-10125',
    storageBucket: 'storeordering-10125.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB7eD5X6kL9mN2pO3qR4sT5uV6wX7yZ8aB',
    appId: '1:111416353624:ios:a1b2c3d4e5f6g7h8i9j0k1',
    messagingSenderId: '111416353624',
    projectId: 'storeordering-10125',
    storageBucket: 'storeordering-10125.appspot.com',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyB7eD5X6kL9mN2pO3qR4sT5uV6wX7yZ8aB',
    appId: '1:111416353624:macos:a1b2c3d4e5f6g7h8i9j0k1',
    messagingSenderId: '111416353624',
    projectId: 'storeordering-10125',
    storageBucket: 'storeordering-10125.appspot.com',
  );
}