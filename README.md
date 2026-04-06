# TheChaat

TheChaat is a Flutter-based real-time chat application powered by Firebase Authentication and Cloud Firestore.

## Features

- Email/password authentication (sign up, login, logout)
- Unique username support with availability checks
- 1:1 chat creation by username
- Group chat creation support in the service layer
- Real-time message streaming
- Unread message counters per user
- Read receipts (`isRead` + `readBy`)
- Basic error handling for Firestore permission/index issues

## Tech Stack

- **Framework:** Flutter
- **Language:** Dart
- **State Management:** Riverpod
- **Backend:** Firebase
  - Firebase Auth
  - Cloud Firestore
- **Formatting:** `intl`

## Project Structure

```text
lib/
  main.dart
  models/
    user_model.dart
    chat_model.dart
    message_model.dart
  providers/
    auth_providers.dart
    chat_providers.dart
  screens/
    login_screen.dart
    signup_screen.dart
    chat_list_screen.dart
    chat_screen.dart
  services/
    auth_service.dart
    chat_service.dart
  widgets/
    message_bubble.dart
```

## Prerequisites

- Flutter SDK (compatible with Dart SDK `^3.10.3`)
- Firebase project
- Android Studio / Xcode (depending on target platform)

## Firebase Setup

This project initializes Firebase with:

```dart
await Firebase.initializeApp();
```

Before running, configure Firebase for your app:

1. Create a Firebase project.
2. Enable **Authentication** (Email/Password).
3. Enable **Cloud Firestore**.
4. Register your Flutter app(s) in Firebase.
5. Add Firebase platform config files:
   - Android: `android/app/google-services.json`
   - iOS: `ios/Runner/GoogleService-Info.plist`
6. Ensure package/bundle identifiers match your Firebase app registration.

> Note: This repository currently does not include Firebase config files or `firebase_options.dart`, so you must provide your own Firebase setup.

## Getting Started

From the repository root:

```bash
flutter pub get
flutter run
```

## Quality Checks

Run static analysis and tests:

```bash
flutter analyze
flutter test
```

## Current Status / Notes

- App name and Android application ID are still using template values (`tryapp` / `com.example.tryapp`).
- `test/widget_test.dart` is the default Flutter template test and is not aligned with the current chat app UI.

## Roadmap Ideas

- Add `firebase_options.dart` via FlutterFire CLI
- Add search UX improvements (debounce/results list)
- Add profile screen and avatar support
- Add message media attachments
- Add proper unit/widget/integration tests
