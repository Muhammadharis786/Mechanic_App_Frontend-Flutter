// File generated for Firebase configuration
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
    
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

  // Android configuration from google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAXmrvxeb1hT7PzeL7nD6Gun9U-jXqy1gc',
    appId: '1:587335997638:android:fbdf9b2129f2853f331fc7',
    messagingSenderId: '587335997638',
    projectId: 'onfix-mechanic-finder',
    storageBucket: 'onfix-mechanic-finder.firebasestorage.app',
  );

  // Web configuration - YOU NEED TO GET THIS FROM FIREBASE CONSOLE
  // Go to: Firebase Console > Project Settings > General > Your apps > Web app
  // If no web app exists, click "Add app" and select Web
  static const FirebaseOptions web = FirebaseOptions(
      apiKey: "AIzaSyAoc7HGXuVXUmBRJgj9FKmiFdhhGPIxMfM",
  authDomain: "onfix-mechanic-finder.firebaseapp.com",
  projectId: "onfix-mechanic-finder",
  storageBucket: "onfix-mechanic-finder.firebasestorage.app",
  messagingSenderId: "587335997638",
  appId: "1:587335997638:web:ab9a8c51a7a70693331fc7"
  );

}
