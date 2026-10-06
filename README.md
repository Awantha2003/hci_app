# MindCheck-app
MindCheck — A mental health check-in and counselor booking app for university students

## Tech stack
* **Flutter (Dart)**: one codebase for Android and iOS
* **Firebase Cloud Firestore**: real-time database
* **Provider**: state management

## Setup
1. Install the Flutter SDK (stable) and Android Studio / an Android device.
2. `flutter pub get`
3. Firebase: `dart pub global activate flutterfire_cli`, then `flutterfire configure`
   (creates the Firebase config files), and publish `firestore.rules`.

## Modules

### Booking, Chat & Counselor Dashboard (Rathnayaka)
Book a session, booking confirmation, my appointments, reschedule, anonymous
chat and the counselor dashboard.

* Run on Android (data saved to Firebase project `mindcheck-app-c6452`):
  `flutter run -t lib/dev/booking_chat_demo_main.dart`
* Run with offline sample data instead (also used automatically on web/desktop):
  `flutter run -t lib/dev/booking_chat_demo_main.dart --dart-define=USE_FIREBASE=false`
* Build APK: `flutter build apk --release -t lib/dev/booking_chat_demo_main.dart`
* Tests: `flutter test test/features`
* Details (data model, test cases, integration): [docs/booking_chat_module.md](docs/booking_chat_module.md)
