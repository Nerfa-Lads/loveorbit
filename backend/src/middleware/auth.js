import jwt from 'jsonwebtoken';
import { query } from '../db/index.js';

const SECRET = process.env.JWT_SECRET || 'dev-insecure-secret';

export function signToken(user) {
  return jwt.sign(
    { sub: user.id, email: user.email, couple_id: user.couple_id || null },
    SECRET,
    { expiresIn: '30d' },
  );
}

export async function auth(req, res, next) {
  try {
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : null;
    if (!token) return res.status(401).json({ error: 'unauthorized' });

    const payload = jwt.verify(token, SECRET);
    const { rows } = await query('SELECT id, username, display_name, avatar_url, couple_id FROM users WHERE id = $1', [payload.sub]);
    if (rows.length === 0) return res.status(401).json({ error: 'unauthorized' });

    req.user = rows[0];
    next();
  } catch (err) {
    return res.status(401).json({ error: 'unauthorized' });
  }
}
