-- LoveOrbit schema
-- Works on Neon PostgreSQL (and any standard Postgres).
-- Run with: psql "$DATABASE_URL" -f db/schema.sql
-- or:      npm run db:push   (uses db-migrate-style script in package.json)

CREATE EXTENSION IF NOT EXISTS "pgcrypto";   -- for gen_random_uuid()

-- ============================================================
-- users
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email         TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,                       -- bcrypt
  display_name  TEXT NOT NULL,
  avatar_url    TEXT,
  couple_id     UUID,                                -- set once connected
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_users_couple_id ON users (couple_id) WHERE couple_id IS NOT NULL;

-- ============================================================
-- couples
-- A couple is exactly two users. Both must accept to connect.
-- ============================================================
CREATE TABLE IF NOT EXISTS couples (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code          TEXT NOT NULL UNIQUE,                -- private couple code (e.g. 6 chars)
  creator_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  partner_id    UUID REFERENCES users(id) ON DELETE CASCADE, -- NULL until someone joins
  creator_accepted   BOOLEAN NOT NULL DEFAULT TRUE,
  partner_accepted   BOOLEAN NOT NULL DEFAULT FALSE,
  status        TEXT NOT NULL DEFAULT 'pending'     -- pending | active | disconnected
                CHECK (status IN ('pending','active','disconnected')),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_couples_code ON couples (code);
CREATE INDEX IF NOT EXISTS idx_couples_status ON couples (status);

-- Back-reference from users -> couples
DO $$ BEGIN
  ALTER TABLE users ADD CONSTRAINT fk_users_couple
    FOREIGN KEY (couple_id) REFERENCES couples(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- locations
-- One row per partner location update. client_uid is a client-generated
-- unique id used to dedupe offline-synced rows.
-- ============================================================
CREATE TABLE IF NOT EXISTS locations (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  couple_id   UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  latitude    DOUBLE PRECISION NOT NULL,
  longitude   DOUBLE PRECISION NOT NULL,
  accuracy    DOUBLE PRECISION,
  speed       DOUBLE PRECISION,
  heading     DOUBLE PRECISION,
  altitude    DOUBLE PRECISION,
  recorded_at TIMESTAMPTZ NOT NULL,                 -- when GPS fixed it
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),   -- when server stored it
  client_uid  TEXT NOT NULL,                        -- dedupe key from device
  UNIQUE (user_id, client_uid)
);
CREATE INDEX IF NOT EXISTS idx_locations_user_time ON locations (user_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_locations_couple_time ON locations (couple_id, recorded_at DESC);

-- ============================================================
-- media
-- Photos shared in chat. Stored on disk/object storage; url points to it.
-- Must be created before messages so the FK reference resolves.
-- ============================================================
CREATE TABLE IF NOT EXISTS media (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id    UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  uploader_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  url          TEXT NOT NULL,
  content_type TEXT NOT NULL DEFAULT 'image/jpeg',
  byte_size    INTEGER NOT NULL DEFAULT 0,
  width        INTEGER,
  height       INTEGER,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_media_couple_time ON media (couple_id, created_at DESC);

-- ============================================================
-- messages
-- sender_id / receiver_id are the two partners. client_uid dedupes offline sends.
-- ============================================================
CREATE TABLE IF NOT EXISTS messages (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id    UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  sender_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  receiver_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body         TEXT,
  media_id     UUID REFERENCES media(id) ON DELETE SET NULL,
  status       TEXT NOT NULL DEFAULT 'sent'         -- sent | delivered | read
               CHECK (status IN ('sent','delivered','read')),
  created_at   TIMESTAMPTZ NOT NULL,
  client_uid   TEXT NOT NULL,
  UNIQUE (sender_id, client_uid)
);
CREATE INDEX IF NOT EXISTS idx_messages_couple_time ON messages (couple_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_receiver_status ON messages (receiver_id, status);

-- ============================================================
-- device_tokens  (push notifications)
-- ============================================================
CREATE TABLE IF NOT EXISTS device_tokens (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token      TEXT NOT NULL,
  platform   TEXT NOT NULL DEFAULT 'android',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, token)
);
CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON device_tokens (user_id);

-- ============================================================
-- sharing state  (whether each user is currently sharing location)
-- ============================================================
CREATE TABLE IF NOT EXISTS sharing_state (
  user_id     UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  couple_id   UUID REFERENCES couples(id) ON DELETE CASCADE,
  sharing     BOOLEAN NOT NULL DEFAULT FALSE,
  paused      BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- updated_at trigger helper
-- ============================================================
CREATE OR REPLACE FUNCTION touch_updated_at()
RETURNS TRIGGER AS $$ BEGIN
  NEW.updated_at = now(); RETURN NEW; END; $$ LANGUAGE plpgsql;

DO $$ BEGIN
  CREATE TRIGGER users_touch   BEFORE UPDATE ON users   FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TRIGGER couples_touch BEFORE UPDATE ON couples FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TRIGGER device_tokens_touch BEFORE UPDATE ON device_tokens FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
