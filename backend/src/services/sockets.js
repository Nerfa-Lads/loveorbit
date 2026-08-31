import { Server } from 'socket.io';
import jwt from 'jsonwebtoken';
import { query } from '../db/index.js';

const SECRET = process.env.JWT_SECRET || 'dev-insecure-secret';

export function attachSockets(httpServer) {
  const io = new Server(httpServer, {
    cors: { origin: '*', methods: ['GET', 'POST'] },
  });

  // auth middleware on socket connection
  io.use((socket, next) => {
    try {
      const token = socket.handshake.auth?.token || socket.handshake.query?.token;
      if (!token) return next(new Error('unauthorized'));
      const payload = jwt.verify(token, SECRET);
      socket.userId = payload.sub;
      socket.coupleId = payload.couple_id || null;
      next();
    } catch (e) {
      next(new Error('unauthorized'));
    }
  });

  io.on('connection', async (socket) => {
    const userId = socket.userId;
    let coupleId = socket.coupleId;
    // refresh couple id from db in case it changed since token issued
    const { rows } = await query('SELECT couple_id FROM users WHERE id = $1', [userId]);
    if (rows[0]?.couple_id) {
      coupleId = rows[0].couple_id;
      socket.coupleId = coupleId;
    }
    socket.join(`user:${userId}`);
    if (coupleId) socket.join(`couple:${coupleId}`);
    await query('UPDATE sharing_state SET updated_at = now() WHERE user_id = $1', [userId]).catch(() => {});

    // ── Helper: forward event to partner only (not sender) ──
    const toPartner = (event, data) => {
      if (!coupleId) return;
      socket.to(`couple:${coupleId}`).emit(event, { user_id: userId, ...data });
    };

    socket.on('location:update', (data) => toPartner('location:update', data));
    socket.on('sharing:toggle', (data) => toPartner('sharing:toggle', data));
    socket.on('typing', () => toPartner('typing', {}));

    // ── Chat messages ──────────────────────────────────────
    socket.on('message:send', (data) => {
      if (!coupleId) return;
      socket.to(`couple:${coupleId}`).emit('message:new', {
        ...data,
        sender_id: userId,
      });
    });

    socket.on('message:status', (data) => toPartner('message:status', data));

    // ── Home arrived ───────────────────────────────────────
    socket.on('home:arrived', async (data) => {
      if (!coupleId) return;
      const { rows: userRows } = await query('SELECT display_name FROM users WHERE id = $1', [userId]);
      const name = userRows[0]?.display_name || 'Your partner';
      socket.to(`couple:${coupleId}`).emit('home:arrived', {
        user_id: userId,
        display_name: name,
        timestamp: data?.timestamp || new Date().toISOString(),
      });
    });

    // ── Home pin ───────────────────────────────────────────
    socket.on('home:pin', (data) => toPartner('home:pin', data));

    // ── Battery ────────────────────────────────────────────
    socket.on('battery:update', (data) => toPartner('battery:update', data));

    // ── Phone active state ─────────────────────────────────
    socket.on('phone:active', (data) => toPartner('phone:active', data));

    // ── Pin color ──────────────────────────────────────────
    socket.on('pin:color', (data) => toPartner('pin:color', data));

    // ── Saved places ───────────────────────────────────────
    socket.on('places:sync', (data) => toPartner('places:sync', data));

    // ── Movement mode ──────────────────────────────────────
    socket.on('movement:update', (data) => toPartner('movement:update', data));

    // ── Place arrived notification ─────────────────────────
    socket.on('place:arrived', async (data) => {
      if (!coupleId) return;
      const { rows: userRows } = await query('SELECT display_name FROM users WHERE id = $1', [userId]);
      const name = userRows[0]?.display_name || 'Your partner';
      socket.to(`couple:${coupleId}`).emit('place:arrived', {
        user_id: userId,
        display_name: name,
        label: data?.label || '',
        timestamp: data?.timestamp || new Date().toISOString(),
      });
    });

    // ── Current place ──────────────────────────────────────
    socket.on('current:place', (data) => toPartner('current:place', data));

    // ── Sync request: ask partner to re-broadcast all their state ─────
    // Emitted by a client right after it connects so it receives the
    // partner's latest home pin, places, battery, pin color, etc.
    socket.on('sync:request', () => toPartner('sync:request', {}));

    socket.on('disconnect', () => {});
  });

  return io;
}
