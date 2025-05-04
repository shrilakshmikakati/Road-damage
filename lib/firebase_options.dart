import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;


class DefaultFirebaseOptions{
  static FirebaseOptions get currentPlatform {
    // Replace with your actual Firebase config values
    return const FirebaseOptions(
      apiKey: 'YOUR_API_KEY',
      appId: 'YOUR_APP_ID',
      messagingSenderId: 'YOUR_SENDER_ID',
      projectId: 'YOUR_PROJECT_ID',
      storageBucket: 'YOUR_STORAGE_BUCKET',
    );
  }
}