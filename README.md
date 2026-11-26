# UrbanEye – Civic Issue Reporting (Flutter + Firebase)

Covers Sprint 1 & 2 (22 user stories): Citizen, Field Worker, Department Admin and Super Admin roles.

## 1. Prerequisites
| Tool | Version |
|---|---|
| Flutter SDK | 3.24+ (stable) |
| Dart SDK | 3.3+ (bundled with Flutter) |
| Android Studio | Koala (2024.1) or newer, with Flutter + Dart plugins |
| Android SDK | API 34 + build-tools, platform-tools; JDK 17 (bundled with Android Studio) |
| Node.js | 20 LTS (Cloud Functions) |
| Firebase CLI | `npm i -g firebase-tools` then `firebase login` |
| FlutterFire CLI | `dart pub global activate flutterfire_cli` |

Run `flutter doctor` and fix anything marked ✗.

## 2. Extract & Open in Android Studio
1. Unzip `urbaneye.zip`.
2. Android Studio → **File ▸ Open** → select the `urbaneye` folder (the one containing `pubspec.yaml`).
3. **Settings ▸ Languages & Frameworks ▸ Flutter**: set the Flutter SDK path. Android Studio writes `android/local.properties` for you (or create it with `flutter.sdk=/path/to/flutter` and `sdk.dir=/path/to/Android/sdk`).
4. Open a terminal in the project and run `flutter pub get`.
5. Let Gradle sync. If Gradle complains about missing wrapper files, run once: `flutter create . --platforms=android` (non-destructive; it only adds missing files) and sync again.
6. Set your Google Maps key in `android/app/src/main/AndroidManifest.xml` (`YOUR_GOOGLE_MAPS_API_KEY`).

## 3. Firebase Setup
1. Create a project at https://console.firebase.google.com.
2. Enable: **Authentication ▸ Phone** and **Email link (passwordless)**; **Firestore**; **Storage**; **Cloud Messaging**. Upgrade to **Blaze** (required for Cloud Functions and SMS).
3. Add your phone's/emulator's SHA-1 and SHA-256 (`cd android && ./gradlew signingReport`) in Project settings ▸ Android app (package `com.urbaneye.app`). Add test phone numbers under Auth ▸ Phone for development.
4. Auth ▸ Settings ▸ Authorized domains: add `urbaneye.page.link` (or your own domain used in `ActionCodeSettings`).
5. From the project root: `flutterfire configure` (overwrites `lib/firebase_options.dart` and downloads `android/app/google-services.json`).
6. Install the **Trigger Email from Firestore** extension (collection `mail`) so admin invitation emails are sent.
7. Deploy backend:
   ```
   cd functions && npm install && cd ..
   firebase deploy --only firestore:rules,firestore:indexes,storage,functions
   ```
8. **Create the first Super Admin**: sign in once with a phone number in the app, then in Firebase Console ▸ Firestore ▸ `users/{uid}` set `role` = `super_admin`. Use the Super Admin screen to invite department admins and the 6 departments' admins.
9. Field workers: set `role` = `field_worker` on their `users/{uid}` doc, then assign reports to their UID from the admin dashboard.

## 4. Change the Logo & Pictures (No Code)
Folder: `assets/images/`

| File | Used for | Recommended size |
|---|---|---|
| `logo.png` | Splash, login, success screen, launcher source | ~1200×700 px PNG (transparent OK) |
| `logo_light.png` | Logo variant for dark backgrounds | same |
| `placeholder_report.png` | Report card when no photo | 600×400 |
| `empty_state.png` | Empty lists | 600×400 |

Replace a file with a new image **using the same filename**, then stop the app and run `flutter run` again (or `flutter clean && flutter run`). All paths live in `lib/core/constants/app_assets.dart`; the logo is drawn by `lib/widgets/app_logo.dart` (`BoxFit.contain`, icon fallback if the file is missing). The Android launcher icon is separate: replace `android/app/src/main/res/mipmap-*/ic_launcher.png` (or use the `flutter_launcher_icons` package).

## 5. Running & Testing
- Emulator/device: `flutter devices` then `flutter run` (or press ▶ in Android Studio). Use an emulator image with **Google Play** for Maps/Phone Auth.
- Tests: `flutter test`
- Firebase Emulator Suite: `firebase emulators:start` (Auth 9099, Firestore 8080, Functions 5001, Storage 9199, UI 4000). To point the app at it, add `FirebaseAuth.instance.useAuthEmulator('10.0.2.2', 9099)` etc. in `main.dart` for debug builds.

## Architecture notes
- State: Riverpod. Navigation: GoRouter with role-based redirect (`lib/router.dart`) → "Access Denied" for cross-role or deactivated users.
- `trackingId` (`UE-<CAT>-<YEAR>-<NNNNN>`), priority score, notifications, duplicate search/merge, admin management and report reassignment run in Cloud Functions (`functions/index.js`).
- Public feed reads the sanitized `public_feed` collection (written only by functions), so `reporterId`, phone and email are never exposed.

## Known placeholders – please review
- **Figma**: the Figma Make link could not be opened from this environment, so colors/layouts are inspired by the logo and standard Material 3. Adjust tokens in `lib/core/theme/app_theme.dart`.
- **Ward lookup** (`LocationService.wardFor`) and **municipality boundary** (`AppConstants.bounds`) are approximations; replace with your municipality's ward polygons.
- Admin email-link sign-in: the login screen has a "paste link" step; for one-tap login configure Firebase Dynamic Links/App Links for the `ActionCodeSettings` URL.
- Video 30 s limit is enforced at capture; gallery videos should be length-checked with `video_player` if needed.
- Comment UI is not included (backend trigger `onComment` and rules are); Water & Drainage and Illegal Construction use the generic department dashboard.
- Code was not compiled in this environment (no Flutter SDK available) – run `flutter analyze` and fix any minor issues.
