# StayNear

A Flutter apartment-rental app backed by Firebase (Firestore, Auth, Storage, Functions) and Stripe for payments.

---

## Prerequisites

- Flutter SDK ≥ 3.x
- Firebase CLI (`npm install -g firebase-tools`)
- A Firebase project (`staynear-7a71b`) with Firestore, Auth, Storage, and Functions enabled
- A Stripe account (test mode keys are fine for development)
- A Google Maps API key with the **Maps SDK for Android**, **Maps SDK for iOS**, and (optionally) **Maps JavaScript API** enabled

---

## Stripe Setup

Stripe is initialised at startup via `--dart-define`. The app will launch normally **without** the key, but the payment screen will show an error when the user tries to pay.

### Development / local run

```bash
flutter run --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_XXXXXXXXXXXX
```

### Build (release)

```bash
flutter build apk --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_XXXXXXXXXXXX
flutter build ipa --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_XXXXXXXXXXXX
```

> **Never commit your real Stripe key to source control.** Store it in a CI secret or a local `.env` file that is git-ignored.

The iOS `AppDelegate.swift` also contains a hardcoded Stripe test key used by the native Stripe SDK. Replace it with your own test key before distributing.

---

## Google Maps Setup

### iOS

The API key is set directly in `ios/Runner/AppDelegate.swift`:

```swift
GMSServices.provideAPIKey("YOUR_IOS_MAPS_API_KEY")
```

Replace the placeholder with your own key. Restrict the key to the **Maps SDK for iOS** and your app's bundle ID in Google Cloud Console.

### Android

The key is injected via a Gradle manifest placeholder — **do not hardcode it in source files**.

1. Open (or create) `android/local.properties` and add:

   ```properties
   MAPS_API_KEY=AIzaSy_YOUR_ANDROID_KEY
   ```

   `local.properties` is listed in `.gitignore` and will not be committed.

2. Alternatively, export the environment variable before building:

   ```bash
   export MAPS_API_KEY=AIzaSy_YOUR_ANDROID_KEY
   flutter run
   ```

The `build.gradle.kts` reads `MAPS_API_KEY` from either the environment or `local.properties` and injects it into `AndroidManifest.xml` as `${MAPS_API_KEY}`. Restrict the key to the **Maps SDK for Android** and your app's SHA-1 certificate in Google Cloud Console.

### Web

Google Maps for Flutter web requires the Maps JavaScript API script tag. In `web/index.html` there is a commented-out block:

```html
<!-- <script src="https://maps.googleapis.com/maps/api/js?key=YOUR_WEB_MAPS_API_KEY"></script> -->
```

1. Uncomment the line.
2. Replace `YOUR_WEB_MAPS_API_KEY` with a key restricted to the **Maps JavaScript API** and your web domain.
3. Do **not** commit the real key; use a build-time substitution or restrict the key by HTTP referrer.

---

## Firebase Setup

### Deploy all rules and indexes

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```

### Deploy individually

```bash
# Firestore rules
firebase deploy --only firestore:rules

# Firestore indexes (takes a few minutes to build)
firebase deploy --only firestore:indexes

# Storage rules
firebase deploy --only storage
```

### Deploy Cloud Functions

```bash
firebase deploy --only functions
```

---

## Running the app

```bash
# Android or iOS (Stripe required for payment screen)
flutter run --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_XXXXXXXXXXXX

# Without Stripe (app launches; payment screen shows setup error)
flutter run
```

---

## Project structure

```
lib/
  main.dart                  # App entry point; Firebase + Stripe init
  features/
    auth/                    # Login, signup, splash, auth gate
    home/                    # Home, search, explore, apartment detail
    booking/                 # Booking flow screens
    payment/                 # Stripe PaymentSheet screen
    host/                    # Host dashboard, property management
    chat/                    # Messaging
    profile/                 # User profile & settings
  models/                    # Dart model classes
  core/                      # Settings, colors, location service
firestore.rules              # Firestore security rules
firestore.indexes.json       # Compound query indexes
storage.rules                # Firebase Storage security rules
firebase.json                # Firebase project config
functions/                   # Cloud Functions (Node.js)
```
