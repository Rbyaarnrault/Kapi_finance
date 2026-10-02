// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions est uniquement configuré pour le Web pour le moment.',
    );
  }

  // Configuration Web avec tes identifiants réels Kapi
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'XXXXXXXXXXXXXXXXXXXXXXXXXX',
    appId: 'XXXXXXXXXXXXXXXXXXXXXXXXXX',
    messagingSenderId: 'XXXXXXXXXXXXXXXXXXXXXXXXXX',
    projectId: 'XXXXXXXXXXXXXXXXXXXXXXXXXX',
    authDomain: 'XXXXXXXXXXXXXXXXXXXXXXXXXX',
    storageBucket: 'XXXXXXXXXXXXXXXXXXXXXXXXXX',
  );
}