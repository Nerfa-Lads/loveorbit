import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import path from 'node:path';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import { attachSockets } from './services/sockets.js';
import authRoutes from './routes/auth.js';
import coupleRoutes from './routes/couples.js';
import locationRoutes from './routes/locations.js';
import messageRoutes from './routes/messages.js';
import mediaRoutes from './routes/media.js';
import deviceRoutes from './routes/devices.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const app = express();
const PORT = parseInt(process.env.PORT || '4000', 10);

app.use(cors());
app.use((req, res, next) => {
  // Skip JSON body parsing for multipart routes (avatar, media upload)
  // so that multer can read the stream itself.
  if (/^\/(api\/auth\/avatar|api\/media)(\/|$)/.test(req.path)) {
    return next();
  }
  express.json({ limit: '20mb' })(req, res, next);
});

// serve uploaded photos
const uploadDir = path.resolve(__dirname, '../uploads');
fs.mkdirSync(uploadDir, { recursive: true });
app.use('/uploads', express.static(uploadDir));

app.get('/health', (_req, res) => res.json({ ok: true, name: 'loveorbit', time: new Date().toISOString() }));

app.use('/api/auth', authRoutes);
app.use('/api/couples', coupleRoutes);
app.use('/api/locations', locationRoutes);
app.use('/api/messages', messageRoutes);
app.use('/api/media', mediaRoutes);
app.use('/api/devices', deviceRoutes);

app.use((err, _req, res, _next) => {
  console.error('[error]', err);
  res.status(500).json({ error: 'server_error' });
});

const server = app.listen(PORT, () => {
  console.log(`LoveOrbit backend on http://localhost:${PORT}`);
});

attachSockets(server);
