import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for Firebase project: urbaneye-14
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
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA_UrbanEye14_AndroidKey_MockVal',
    appId: '1:100000000000:android:1234567890abcdef',
    messagingSenderId: '100000000000',
    projectId: 'urbaneye-14',
    storageBucket: 'urbaneye-14.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA_UrbanEye14_IOSKey_MockVal',
    appId: '1:100000000000:ios:1234567890abcdef',
    messagingSenderId: '100000000000',
    projectId: 'urbaneye-14',
    storageBucket: 'urbaneye-14.appspot.com',
    iosBundleId: 'com.urbaneye.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA_UrbanEye14_WebKey_MockVal',
    appId: '1:100000000000:web:1234567890abcdef',
    messagingSenderId: '100000000000',
    projectId: 'urbaneye-14',
    authDomain: 'urbaneye-14.firebaseapp.com',
    storageBucket: 'urbaneye-14.appspot.com',
  );
}
