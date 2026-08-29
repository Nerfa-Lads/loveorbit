import { Router } from 'express';
import { customAlphabet } from 'nanoid';
import { query } from '../db/index.js';
import { auth } from '../middleware/auth.js';

const router = Router();
// 6-char uppercase code, no ambiguous chars
const codeGen = customAlphabet('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 6);

// POST /api/couples/create  -> create a pending couple (creator auto-accepted)
router.post('/create', auth, async (req, res) => {
  try {
    if (req.user.couple_id) {
      const { rows: cur } = await query('SELECT status FROM couples WHERE id = $1', [req.user.couple_id]);
      if (cur[0]?.status === 'active') return res.status(409).json({ error: 'already_connected' });
    }
    const code = codeGen();
    const { rows } = await query(
      `INSERT INTO couples (code, creator_id, creator_accepted, status)
       VALUES ($1, $2, TRUE, 'pending') RETURNING *`, [code, req.user.id],
    );
    const couple = rows[0];
    await query('UPDATE users SET couple_id = $1 WHERE id = $2', [couple.id, req.user.id]);
    res.json({ couple });
  } catch (e) {
    console.error('couples create', e);
    res.status(500).json({ error: 'server_error' });
  }
});

// POST /api/couples/join  { code } -> partner joins and accepts
router.post('/join', auth, async (req, res) => {
  try {
    const { code } = req.body || {};
    if (!code) return res.status(400).json({ error: 'code required' });
    const { rows } = await query('SELECT * FROM couples WHERE code = $1 AND status = $2', [code.toUpperCase(), 'pending']);
    if (rows.length === 0) return res.status(404).json({ error: 'code_not_found' });
    const couple = rows[0];
    if (couple.creator_id === req.user.id) return res.status(400).json({ error: 'cannot_join_own_code' });
    if (couple.partner_id && couple.partner_id !== req.user.id) return res.status(409).json({ error: 'code_taken' });

    const { rows: updated } = await query(
      `UPDATE couples SET partner_id = $1, partner_accepted = TRUE, status = 'active', updated_at = now()
       WHERE id = $2 RETURNING *`, [req.user.id, couple.id],
    );
    const c = updated[0];
    await query('UPDATE users SET couple_id = $1 WHERE id IN ($2, $3)', [c.id, c.creator_id, c.partner_id]);
    res.json({ couple: c });
  } catch (e) {
    console.error('couples join', e);
    res.status(500).json({ error: 'server_error' });
  }
});

// GET /api/couples/me
router.get('/me', auth, async (req, res) => {
  try {
    if (!req.user.couple_id) return res.json({ couple: null, partner: null });
    const { rows } = await query('SELECT * FROM couples WHERE id = $1', [req.user.couple_id]);
    if (rows.length === 0) return res.json({ couple: null, partner: null });
    const couple = rows[0];
    const partnerId = couple.creator_id === req.user.id ? couple.partner_id : couple.creator_id;
    let partner = null;
    if (partnerId) {
      const p = await query('SELECT id, display_name, avatar_url FROM users WHERE id = $1', [partnerId]);
      partner = p.rows[0] || null;
    }
    // connected_at = when the couple became active (partner joined)
    res.json({ couple: { ...couple, connected_at: couple.updated_at }, partner });
  } catch (e) {
    console.error('couples me', e);
    res.status(500).json({ error: 'server_error' });
  }
});

// POST /api/couples/disconnect
router.post('/disconnect', auth, async (req, res) => {
  try {
    if (!req.user.couple_id) return res.status(400).json({ error: 'not_connected' });
    const { rows } = await query('SELECT * FROM couples WHERE id = $1', [req.user.couple_id]);
    if (rows.length === 0) return res.json({ ok: true });
    const c = rows[0];
    await query('UPDATE couples SET status = $1, updated_at = now() WHERE id = $2', ['disconnected', c.id]);
    await query('UPDATE users SET couple_id = NULL WHERE couple_id = $1', [c.id]);
    await query('UPDATE sharing_state SET sharing = FALSE, paused = FALSE WHERE couple_id = $1', [c.id]);
    res.json({ ok: true });
  } catch (e) {
    console.error('couples disconnect', e);
    res.status(500).json({ error: 'server_error' });
  }
});

export default router;
