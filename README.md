# LoveOrbit

> Always connected, wherever we are.

LoveOrbit is a private location-sharing app for two consenting partners.
The name: **Love** is our call sign, **Orbit** is where we are — connected wherever we go.

This repo contains two parts:

```
loveorbit/
├── backend/      Node.js + Express + Socket.IO + Neon Postgres
└── app/          Flutter + Dart (Android-first)
```

## What it does

- **Account** — register, login, logout, profile + profile picture
- **Connect partner** — generate a private couple code, partner enters it, both must accept.
  Only two people can be connected. Disconnect at any time.
- **Live location** — your location and your partner's shared location on an OpenStreetMap,
  with last-updated time and an ON/OFF sharing indicator. Either person can pause/stop sharing.
- **Location history** — saved with date/time, shown on a map as a route, filterable by day, deletable.
- **Offline tracking** — GPS keeps recording with no internet, saved to local SQLite as "pending",
  auto-uploaded to Neon when back online. No duplicates, nothing lost.
- **Chat** — private real-time text chat with timestamps and sent/delivered/read status.
- **Offline chat** — messages saved locally when offline, auto-sent when online, no duplicates.
- **Photo sharing** — take a photo or pick from gallery, compress before upload, send in chat.
  Offline photos queue locally and upload when back online.
- **Notifications** — new messages, new photos, partner connection requests, connection accepted.
  (No notifications on every location change.)
- **Privacy** — turn sharing ON/OFF, pause, delete history, disconnect partner, delete account.
  The app clearly shows when sharing is active.

## Tech stack

- **App:** Flutter + Dart (Android first)
- **Backend:** Node.js + Express + Socket.IO
- **Database:** Neon PostgreSQL (online) — schema is plain SQL and works on any Postgres
- **Offline:** SQLite on device
- **Real-time:** Socket.IO
- **Maps:** OpenStreetMap (via flutter_map)
- **Secrets:** environment variables only — never bundled in the app

## Quick start

See [`docs/SETUP.md`](docs/SETUP.md) for full instructions. Short version:

```bash
# 1. Backend
cd backend
cp .env.example .env       # fill in DATABASE_URL, JWT_SECRET, PORT
npm install
npm run db:push            # create tables on Neon
npm run dev

# 2. App
cd app
flutter pub get
# set BACKEND_URL in lib/src/config/app_config.dart
flutter run                # on an Android device/emulator
```

## Consent & privacy by design

- Both partners must accept the connection before any location or chat is shared.
- No secret or hidden tracking — sharing status is always visible.
- Either partner can stop sharing or disconnect at any time.
- Pending offline data is only deleted after the server confirms it was saved.

## Status

This is a complete source tree ready to build and run on your machine.
The build environment that generated this code does not include the Flutter SDK or an Android
emulator, so the APK is not pre-compiled — run `flutter run` locally to build and launch.
