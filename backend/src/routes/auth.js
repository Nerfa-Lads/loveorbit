import bcrypt from 'bcryptjs';
import { Router } from 'express';
import { query } from '../db/index.js';
import { signToken, auth } from '../middleware/auth.js';

const router = Router();

// POST /api/auth/register
router.post('/register', async (req, res) => {
  try {
    const { email, password, display_name } = req.body || {};
    if (!email || !password || !display_name) {
      return res.status(400).json({ error: 'email, password and display_name are required' });
    }
    const exists = await query('SELECT id FROM users WHERE email = $1', [email]);
    if (exists.rowCount > 0) return res.status(409).json({ error: 'email already registered' });

    const hash = await bcrypt.hash(password, 10);
    const { rows } = await query(
      'INSERT INTO users (email, password_hash, display_name) VALUES ($1,$2,$3) RETURNING id, email, display_name, avatar_url, couple_id',
      [email.toLowerCase(), hash, display_name],
    );
    const user = rows[0];
    const token = signToken(user);
    res.json({ token, user });
  } catch (e) {
    console.error('register', e);
    res.status(500).json({ error: 'server_error' });
  }
});

// POST /api/auth/login
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body || {};
    if (!email || !password) return res.status(400).json({ error: 'email and password are required' });
    const { rows } = await query('SELECT * FROM users WHERE email = $1', [email.toLowerCase()]);
    if (rows.length === 0) return res.status(401).json({ error: 'invalid credentials' });

    const user = rows[0];
    const ok = await bcrypt.compare(password, user.password_hash);
    if (!ok) return res.status(401).json({ error: 'invalid credentials' });

    const safe = { id: user.id, email: user.email, display_name: user.display_name, avatar_url: user.avatar_url, couple_id: user.couple_id };
    const token = signToken(safe);
    res.json({ token, user: safe });
  } catch (e) {
    console.error('login', e);
    res.status(500).json({ error: 'server_error' });
  }
});

// GET /api/auth/me
router.get('/me', auth, async (req, res) => {
  res.json({ user: req.user });
});

// PUT /api/auth/profile  (display_name, avatar_url)
router.put('/profile', auth, async (req, res) => {
  try {
    const { display_name, avatar_url } = req.body || {};
    const { rows } = await query(
      `UPDATE users SET display_name = COALESCE($1, display_name), avatar_url = COALESCE($2, avatar_url) WHERE id = $3
       RETURNING id, email, display_name, avatar_url, couple_id`,
      [display_name || null, avatar_url || null, req.user.id],
    );
    res.json({ user: rows[0] });
  } catch (e) {
    console.error('profile', e);
    res.status(500).json({ error: 'server_error' });
  }
});

// DELETE /api/auth/account
router.delete('/account', auth, async (req, res) => {
  try {
    // ON DELETE CASCADE removes locations, messages, media, device_tokens.
    // couples rows are cleaned up by FK cascades from the user side.
    await query('DELETE FROM users WHERE id = $1', [req.user.id]);
    res.json({ ok: true });
  } catch (e) {
    console.error('account', e);
    res.status(500).json({ error: 'server_error' });
  }
});

export default router;
