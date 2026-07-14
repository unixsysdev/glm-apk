# Geepity for Android

A Flutter AI chat client with model selection, conversation history, secure API-key storage, Firebase synchronization, and Android push notifications.

## Features

- Streaming AI conversations with Markdown rendering
- Google sign-in and Firestore-synced conversations
- Secure local credential storage
- Model selection, conversation export, and sharing
- Image and file selection
- Firebase Cloud Messaging notifications

## Stack

Flutter, Dart, Riverpod, Firebase, Hive, and Flutter Secure Storage.

## Setup

```bash
flutter pub get
```

Create the `.env` file loaded by `lib/main.dart`:

```dotenv
FIREBASE_API_KEY=
FIREBASE_APP_ID=
FIREBASE_MESSAGING_SENDER_ID=
FIREBASE_PROJECT_ID=
FIREBASE_STORAGE_BUCKET=
```

The Android application ID and Firebase project must match your Firebase configuration. Never commit service-account credentials or private provider keys.

```bash
flutter run
flutter build apk --release
```

## Structure

- `lib/features/` — authentication, chat, conversations, and settings
- `lib/services/` — AI API, Firestore, storage, and export integrations
- `functions/` — Firebase Functions
- `android/` — Android configuration

## Status

Experimental client. Review Firebase rules, backend authorization, secret handling, billing controls, and provider terms before production distribution.
