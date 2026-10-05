# Duo — a private real-time drawing app for two

**Flutter · Dart · Riverpod · Cloud Firestore · Firebase Auth / Storage / Messaging · Kotlin (Android widget)**

One person draws and taps **Send**; the drawing appears on the other person's phone a moment later, replayed stroke by
stroke. No feed, no likes, no followers: just a shared space for two people.

I designed and built Duo end to end in September 2026 (≈ 9,000 lines of Dart, 39 unit tests, 25 security-rule tests),
and shipped it to real users on Android through Firebase App Distribution, with in-app updates.

> 📸 *Screenshots coming soon.*

## Features

- **Pairing** with a 7-day invite code (`LOVE-7K42QX`), one partner per account
- **Drawing canvas** with a fixed 3:4 ratio (identical on every screen), full colour picker, brush sizes and styles
  (highlighter, neon), eraser, undo/redo, pinch-to-zoom, stylus support with palm rejection
- **Vector storage**: drawings are saved as timestamped strokes, not bitmaps, so they can be replayed and stay light;
  a Ramer–Douglas–Peucker simplifier removes 60–80 % of the points before upload (Firestore documents are capped at 1 MiB)
- **Real-time sync** through Cloud Firestore listeners
- **Offline first**: a local outbox queues drawings and resends them when the network returns, with retry and
  concurrency handling
- **Notifications without a paid backend**: immediate while the app is in the background, otherwise an Android
  WorkManager check every ~15 minutes
- **Home-screen widget** (Kotlin) showing the last drawing received
- Stickers and emoji stamps, visual replies, private history, PNG export, light/dark theme, account deletion

## Architecture

Clean Architecture with Riverpod for dependency injection and state:

```
lib/
├── models/        entities + (de)serialisation (vector Stroke, Drawing, Couple…)
├── domain/        repository contracts (pure interfaces)
├── data/          Firestore/Auth implementations + local outbox
├── services/      Firebase bootstrap, FCM, connectivity, sync, audio, widget, in-app update
├── providers/     Riverpod providers (auth, couple, drawing, settings, services)
├── presentation/  screens (onboarding, home, canvas, history, settings)
├── widgets/       canvas, painter, palette, reusable components
└── core/          theme, router, constants, utils
```

Design choices worth noting:

- **Security rules as the real backend.** With no server on the free Firebase plan, `firestore.rules` and
  `storage.rules` enforce everything sensitive: users only read their own couple's data, can only write drawings
  they send to their partner, can only join with an active, unexpired invite, and cannot list couples or invites.
  These rules are tested against the Firestore emulator (`rules-tests/`).
- **Strokes as data** (points with relative timestamps) make a future *live drawing* mode a matter of streaming
  points, without changing the storage model.
- **Resilient streams**: right after a write, the local cache can announce data the server has not stored yet, and a
  listener opened in that window is rejected by the rules and closed for good. Listeners are wrapped to retry these
  transient `permission-denied` errors with back-off instead of leaving the UI frozen.

## Run it

Requirements: Flutter 3.22+, a Firebase project, Node.js 20+ (for the rules tests).

```bash
flutter pub get
dart pub global activate flutterfire_cli
flutterfire configure          # generates lib/firebase_options.dart and google-services.json
flutter run
```

In the Firebase console, enable **Authentication → Anonymous**, **Firestore**, **Storage** and **Cloud Messaging**.

```bash
flutter test                                        # 39 unit tests
cd rules-tests && npm install && npm test           # security rules, Firestore emulator
firebase deploy --only firestore:rules,firestore:indexes
flutter build apk --release
```

With a single phone, a simulated partner can join and send a drawing:
`cd rules-tests && DUO_API_KEY=<your web API key> node partner-sim.js join LOVE-XXXXXX`.

`functions/` holds an optional Cloud Function for instant server-side push; it requires the paid Blaze plan and is
not used by default.

## Roadmap

- Live mode: a `couples/{id}/live/{sessionId}` sub-collection with batched points and optimistic local rendering
- iOS support (notifications and widget)
- Thumbnails generated at send time for lighter history loading

## Resumen en español

Aplicación móvil privada para dos personas: uno dibuja, envía, y el dibujo aparece casi al instante en el teléfono
del otro. Flutter + Firebase, arquitectura limpia con Riverpod, almacenamiento vectorial de los trazos, modo sin
conexión, notificaciones sin servidor y reglas de seguridad probadas. Diseñada, desarrollada y distribuida en Android
por mí en septiembre de 2026.
