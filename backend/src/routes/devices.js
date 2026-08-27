import { Router } from 'express';
import { query } from '../db/index.js';
import { auth } from '../middleware/auth.js';

const router = Router();

// POST /api/devices  { token, platform }
router.post('/', auth, async (req, res) => {
  try {
    const { token, platform } = req.body || {};
    if (!token) return res.status(400).json({ error: 'token required' });
    await query(
      `INSERT INTO device_tokens (user_id, token, platform) VALUES ($1,$2,$3)
       ON CONFLICT (user_id, token) DO UPDATE SET updated_at = now()`,
      [req.user.id, token, platform || 'android'],
    );
    res.json({ ok: true });
  } catch (e) {
    console.error('device register', e);
    res.status(500).json({ error: 'server_error' });
  }
});

// DELETE /api/devices  { token }
router.delete('/', auth, async (req, res) => {
  try {
    const { token } = req.body || {};
    if (!token) return res.status(400).json({ error: 'token required' });
    await query('DELETE FROM device_tokens WHERE user_id = $1 AND token = $2', [req.user.id, token]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: 'server_error' });
  }
});

export default router;
