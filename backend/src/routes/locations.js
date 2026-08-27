import { Router } from 'express';
import { query } from '../db/index.js';
import { auth } from '../middleware/auth.js';

const router = Router();

async function assertPartner(req) {
  if (!req.user.couple_id) throw { status: 400, error: 'not_connected' };
  const { rows } = await query('SELECT status FROM couples WHERE id = $1', [req.user.couple_id]);
  if (rows.length === 0 || rows[0].status !== 'active') throw { status: 403, error: 'couple_not_active' };
}

// POST /api/locations  (batch upsert from offline sync)  body: { points: [...] }
router.post('/', auth, async (req, res) => {
  try {
    await assertPartner(req);
    const points = Array.isArray(req.body?.points) ? req.body.points : [];
    if (points.length === 0) return res.json({ saved: 0 });

    const saved = [];
    for (const p of points) {
      const { rows } = await query(
        `INSERT INTO locations (user_id, couple_id, latitude, longitude, accuracy, speed, heading, altitude, recorded_at, client_uid)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
         ON CONFLICT (user_id, client_uid) DO NOTHING
         RETURNING id, client_uid`,
        [req.user.id, req.user.couple_id, p.latitude, p.longitude, p.accuracy ?? null, p.speed ?? null,
         p.heading ?? null, p.altitude ?? null, p.recorded_at, p.client_uid],
      );
      if (rows[0]) saved.push(rows[0].client_uid);
    }
    res.json({ saved: saved.length, saved_uids: saved });
  } catch (e) {
    const status = e?.status || 500;
    console.error('locations post', e);
    res.status(status).json({ error: e?.error || 'server_error' });
  }
});

// GET /api/locations/me?from=&to=  -> my own history
router.get('/me', auth, async (req, res) => {
  try {
    const from = req.query.from;
    const to = req.query.to;
    const { rows } = await query(
      `SELECT id, latitude, longitude, accuracy, recorded_at
       FROM locations WHERE user_id = $1
       AND ($2::timestamptz IS NULL OR recorded_at >= $2)
       AND ($3::timestamptz IS NULL OR recorded_at <= $3)
       ORDER BY recorded_at ASC`,
      [req.user.id, from || null, to || null],
    );
    res.json({ points: rows });
  } catch (e) {
    console.error('locations me', e);
    res.status(500).json({ error: 'server_error' });
  }
});

// GET /api/locations/partner?from=&to=  -> partner's history (only if couple active)
router.get('/partner', auth, async (req, res) => {
  try {
    await assertPartner(req);
    const { rows: c } = await query('SELECT creator_id, partner_id FROM couples WHERE id = $1', [req.user.couple_id]);
    const partnerId = c[0].creator_id === req.user.id ? c[0].partner_id : c[0].creator_id;
    const from = req.query.from;
    const to = req.query.to;
    const { rows } = await query(
      `SELECT id, latitude, longitude, accuracy, recorded_at
       FROM locations WHERE user_id = $1
       AND ($2::timestamptz IS NULL OR recorded_at >= $2)
       AND ($3::timestamptz IS NULL OR recorded_at <= $3)
       ORDER BY recorded_at ASC`,
      [partnerId, from || null, to || null],
    );
    res.json({ points: rows });
  } catch (e) {
    const status = e?.status || 500;
    console.error('locations partner', e);
    res.status(status).json({ error: e?.error || 'server_error' });
  }
});

// GET /api/locations/partner/latest
router.get('/partner/latest', auth, async (req, res) => {
  try {
    await assertPartner(req);
    const { rows: c } = await query('SELECT creator_id, partner_id FROM couples WHERE id = $1', [req.user.couple_id]);
    const partnerId = c[0].creator_id === req.user.id ? c[0].partner_id : c[0].creator_id;
    const { rows } = await query(
      `SELECT id, latitude, longitude, accuracy, recorded_at FROM locations
       WHERE user_id = $1 ORDER BY recorded_at DESC LIMIT 1`, [partnerId],
    );
    res.json({ point: rows[0] || null });
  } catch (e) {
    const status = e?.status || 500;
    console.error('locations partner latest', e);
    res.status(status).json({ error: e?.error || 'server_error' });
  }
});

// DELETE /api/locations/me?from=&to=  -> delete my history (or all if no range)
router.delete('/me', auth, async (req, res) => {
  try {
    const from = req.query.from;
    const to = req.query.to;
    await query(
      `DELETE FROM locations WHERE user_id = $1
       AND ($2::timestamptz IS NULL OR recorded_at >= $2)
       AND ($3::timestamptz IS NULL OR recorded_at <= $3)`,
      [req.user.id, from || null, to || null],
    );
    res.json({ ok: true });
  } catch (e) {
    console.error('locations delete', e);
    res.status(500).json({ error: 'server_error' });
  }
});

// ---- sharing state ----
// GET /api/locations/sharing
router.get('/sharing', auth, async (req, res) => {
  try {
    const { rows } = await query('SELECT sharing, paused FROM sharing_state WHERE user_id = $1', [req.user.id]);
    res.json({ sharing: rows[0]?.sharing ?? false, paused: rows[0]?.paused ?? false });
  } catch (e) {
    res.status(500).json({ error: 'server_error' });
  }
});

// PUT /api/locations/sharing  { sharing, paused }
router.put('/sharing', auth, async (req, res) => {
  try {
    const { sharing, paused } = req.body || {};
    await query(
      `INSERT INTO sharing_state (user_id, couple_id, sharing, paused, updated_at)
       VALUES ($1, $2, $3, $4, now())
       ON CONFLICT (user_id) DO UPDATE SET sharing = $3, paused = $4, couple_id = COALESCE($2, sharing_state.couple_id), updated_at = now()`,
      [req.user.id, req.user.couple_id || null, !!sharing, !!paused],
    );
    res.json({ ok: true });
  } catch (e) {
    console.error('sharing', e);
    res.status(500).json({ error: 'server_error' });
  }
});

export default router;
