# LoveOrbit — Setup & Testing Guide

This guide walks you through setting up the backend, database, and Flutter app
step by step, and explains how to test each feature.

---

## Prerequisites

- **Flutter** 3.22+ (`flutter doctor` should pass with Android toolchain)
- **Node.js** 18+
- A **Neon** PostgreSQL account (free tier works) — https://neon.tech
- An Android device or emulator
- (Optional) **ngrok** for testing with a real device over wifi

---

## Step 1 — Database (Neon PostgreSQL)

1. Create a free project at https://neon.tech
2. Copy your connection string. It looks like:
   ```
   postgresql://user:password@ep-xxx.neon.tech/loveorbit?sslmode=require
   ```
3. The schema file is at `backend/db/schema.sql`. It creates all 6 tables:
   `users`, `couples`, `locations`, `messages`, `media`, `device_tokens`,
   plus a `sharing_state` table — with relationships, indexes, unique IDs,
   and updated_at triggers.

**Test:** Run the schema push (next step covers this) and check your Neon
console — all tables should appear.

---

## Step 2 — Backend (Node.js + Express + Socket.IO)

```bash
cd backend
cp .env.example .env
# Edit .env:
#   DATABASE_URL=postgresql://user:pass@ep-xxx.neon.tech/loveorbit?sslmode=require
#   JWT_SECRET=<run: openssl rand -hex 32>
#   PORT=4000
#   PUBLIC_BASE_URL=http://localhost:4000

npm install
npm run db:push    # creates all tables on Neon
npm run dev        # starts server with auto-reload
```

You should see: `LoveOrbit backend on http://localhost:4000`

**Test the backend:**
```bash
# Health check
curl http://localhost:4000/health

# Register a user
curl -X POST http://localhost:4000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"secret","display_name":"Test"}'

# You should get back a JWT token and user object.
```

---

## Step 3 — Flutter App

```bash
cd app
flutter pub get
```

**Set the backend URL** in `lib/src/config/app_config.dart`:
- Android emulator: `http://10.0.2.2:4000` (already the default)
- Real device on same wifi: `http://<your-computer-lan-ip>:4000`
- Deployed backend: your public URL

**Run the app:**
```bash
flutter run                    # connected device/emulator
```

**Test login/register:**
1. The app opens to the login screen.
2. Tap "Register" and create an account.
3. After registering, you land on the "Connect Partner" screen.

---

## Step 4 — Couple Connection

1. On your phone: tap "Generate couple code" — you get a 6-character code.
2. On your boyfriend's phone: register, then enter that code and tap "Join".
3. Both phones should now show the Home screen with the partner's name.

**Test:** The code is case-insensitive. You can copy it to clipboard. Only
two people can join — a third person entering the code gets an error.

---

## Step 5 — Live Location

1. On the Home screen, toggle "Location sharing" to ON.
2. Allow location permissions when prompted.
3. Your partner's latest location appears on the map with a "last updated" time.
4. Toggle sharing OFF or tap "Pause" to stop.

**Test:** Turn sharing on, walk around, then check the History tab — your
points should appear. Your partner should see your latest pin on their map.

---

## Step 6 — Offline Location Sync

1. Turn on location sharing.
2. Turn off wifi and mobile data on your phone.
3. Walk around — GPS still records points (saved to local SQLite).
4. Turn internet back on.
5. The app automatically uploads all pending points to Neon.

**Test:** Go to History after reconnecting — all the points from your
offline walk should appear. No duplicates, nothing lost.

---

## Step 7 — Chat

1. Open the Chat tab.
2. Type a message and send.
3. Your partner receives it in real time (Socket.IO).
4. Messages show timestamps and sent/delivered/read status.

**Test:** Send messages back and forth while both online — they should
appear instantly. The checkmark changes from ✓ to ✓✓ to ✓✓ (read).

---

## Step 8 — Offline Chat

1. Turn off internet.
2. Type and send a message — it saves locally as "pending".
3. Turn internet back on.
4. The message sends automatically.

**Test:** Send a few messages offline, reconnect, and verify they all
arrive on your partner's phone. No duplicates.

---

## Step 9 — Photo Sharing

1. In chat, tap the camera icon to take a photo, or the gallery icon to pick one.
2. The photo is compressed (quality 70, max width 1024px) before upload.
3. It appears in the chat as an image.

**Offline test:** Turn off internet, take a photo, send it. Turn internet
back on — the photo uploads automatically.

---

## Step 10 — Notifications

The app sends local notifications for:
- New messages (title = partner name, body = message text)
- New photos ("Sent a photo")

Notifications do NOT fire on every location change.

**Test:** Background the app, have your partner send a message — you
should see a notification in your notification shade.

---

## Step 11 — Privacy & Settings

- **Privacy screen:** toggle sharing, pause, delete history, disconnect, delete account.
- **Settings screen:** edit display name, view couple code, see partner info.
- **Profile screen:** shows your avatar, name, email, and links to Settings/Privacy.

**Test:** Go to Privacy, delete your location history, then check the
History tab — it should be empty. Disconnect your partner — both phones
return to the Connect Partner screen.

---

## Step 12 — Deployment

### Backend (free options)

**Render** (https://render.com):
1. Push this repo to GitHub.
2. Create a new Web Service, connect your repo, set root directory to `backend`.
3. Build command: `npm install`
4. Start command: `npm start`
5. Add environment variables: `DATABASE_URL`, `JWT_SECRET`, `PORT`, `PUBLIC_BASE_URL`.

**Railway** (https://railway.app) works similarly.

### App

1. Update `app_config.dart` with your deployed backend URL.
2. Build the APK:
   ```bash
   cd app
   flutter build apk --release
   ```
3. The APK is at `build/app/outputs/flutter-apk/app-release.apk`.
4. Install on both phones:
   ```bash
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```
   Or copy the APK file to your phones and install manually.

### Neon Database

Neon's free tier includes 0.5 GB storage and 100 compute hours/month —
more than enough for two people sharing locations and chat.

---

## Troubleshooting

- **"Connection refused" on real device:** Make sure your phone and computer
  are on the same wifi, and use your computer's LAN IP (not localhost).
- **Location not updating:** Check that location permissions are granted
  (Settings > Apps > LoveOrbit > Permissions).
- **Socket not connecting:** Verify the backend URL has no trailing slash,
  and that your deployed backend allows WebSocket connections.
- **Photos not uploading:** The backend must have a writable `uploads/`
  directory and `PUBLIC_BASE_URL` must point to the correct public address.
