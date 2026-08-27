import { Router } from 'express';
import { query } from '../db/index.js';
import { auth } from '../middleware/auth.js';

const router = Router();

async function coupleActive(userId) {
  const { rows } = await query('SELECT id, creator_id, partner_id, status FROM couples WHERE id = (SELECT couple_id FROM users WHERE id = $1)', [userId]);
  if (rows.length === 0 || rows[0].status !== 'active') return null;
  return rows[0];
}

// GET /api/messages?limit=100&before=<iso>
router.get('/', auth, async (req, res) => {
  try {
    const couple = await coupleActive(req.user.id);
    if (!couple) return res.status(403).json({ error: 'couple_not_active' });
    const limit = Math.min(parseInt(req.query.limit || '100', 10), 500);
    const before = req.query.before || null;
    const { rows } = await query(
      `SELECT m.id, m.sender_id, m.receiver_id, m.body, m.media_id, m.status, m.created_at, m.client_uid,
              med.url AS media_url, med.content_type AS media_content_type
       FROM messages m LEFT JOIN media med ON med.id = m.media_id
       WHERE m.couple_id = $1
       AND ($2::timestamptz IS NULL OR m.created_at < $2)
       ORDER BY m.created_at DESC LIMIT $3`, [couple.id, before, limit],
    );
    res.json({ messages: rows.reverse() });
  } catch (e) {
    console.error('messages get', e);
    res.status(500).json({ error: 'server_error' });
  }
});

// POST /api/messages  (batch for offline sync)  body: { messages: [...] }
router.post('/', auth, async (req, res) => {
  try {
    const couple = await coupleActive(req.user.id);
    if (!couple) return res.status(403).json({ error: 'couple_not_active' });
    const partnerId = couple.creator_id === req.user.id ? couple.partner_id : couple.creator_id;
    const msgs = Array.isArray(req.body?.messages) ? req.body.messages : [];
    if (msgs.length === 0) return res.json({ saved: [] });

    const saved = [];
    for (const m of msgs) {
      const { rows } = await query(
        `INSERT INTO messages (couple_id, sender_id, receiver_id, body, media_id, status, created_at, client_uid)
         VALUES ($1,$2,$3,$4,$5,'sent',$6,$7)
         ON CONFLICT (sender_id, client_uid) DO NOTHING
         RETURNING id, client_uid`,
        [couple.id, req.user.id, partnerId, m.body || null, m.media_id || null, m.created_at, m.client_uid],
      );
      if (rows[0]) saved.push({ client_uid: rows[0].client_uid, id: rows[0].id });
    }
    res.json({ saved });
  } catch (e) {
    console.error('messages post', e);
    res.status(500).json({ error: 'server_error' });
  }
});

// POST /api/messages/status  { message_ids: [...], status: 'delivered'|'read' }
router.post('/status', auth, async (req, res) => {
  try {
    const { message_ids, status } = req.body || {};
    if (!Array.isArray(message_ids) || !['delivered', 'read'].includes(status)) {
      return res.status(400).json({ error: 'invalid' });
    }
    if (message_ids.length === 0) return res.json({ updated: 0 });
    const { rowCount } = await query(
      `UPDATE messages SET status = $1 WHERE receiver_id = $2 AND id = ANY($3::uuid[])`,
      [status, req.user.id, message_ids],
    );
    res.json({ updated: rowCount });
  } catch (e) {
    console.error('messages status', e);
    res.status(500).json({ error: 'server_error' });
  }
});

export default router;
