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

    socket.on('location:update', async (data) => {
      if (!coupleId) return;
      io.to(`couple:${coupleId}`).emit('location:update', { user_id: userId, ...data });
    });

    socket.on('message:send', async (data) => {
      if (!coupleId) return;
      io.to(`couple:${coupleId}`).emit('message:new', { ...data, sender_id: userId });
    });

    socket.on('message:status', async (data) => {
      if (!coupleId) return;
      io.to(`couple:${coupleId}`).emit('message:status', { ...data, by: userId });
    });

    socket.on('sharing:toggle', async (data) => {
      if (!coupleId) return;
      io.to(`couple:${coupleId}`).emit('sharing:toggle', { user_id: userId, ...data });
    });

    socket.on('typing', () => {
      if (coupleId) socket.to(`couple:${coupleId}`).emit('typing', { user_id: userId });
    });

    socket.on('disconnect', () => {});
  });

  return io;
}
