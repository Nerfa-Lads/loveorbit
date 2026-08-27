import { Router } from 'express';
import multer from 'multer';
import path from 'node:path';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import { query } from '../db/index.js';
import { auth } from '../middleware/auth.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const uploadDir = path.resolve(__dirname, '../../uploads');
fs.mkdirSync(uploadDir, { recursive: true });

const router = Router();

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname || '.jpg') || '.jpg';
    cb(null, `${req.user.id}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}${ext}`);
  },
});
const upload = multer({
  storage,
  limits: { fileSize: 15 * 1024 * 1024 }, // 15MB; client compresses before upload
  fileFilter: (_req, file, cb) => {
    if (!/^image\//.test(file.mimetype || '')) return cb(new Error('images_only'));
    cb(null, true);
  },
});

function publicUrl(filename) {
  const base = process.env.PUBLIC_BASE_URL || 'http://localhost:4000';
  return `${base}/uploads/${filename}`;
}

// POST /api/media  multipart field "photo"
router.post('/', auth, upload.single('photo'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'no_file' });
    const url = publicUrl(req.file.filename);
    const { rows } = await query(
      `INSERT INTO media (couple_id, uploader_id, url, content_type, byte_size)
       VALUES ($1,$2,$3,$4,$5) RETURNING id, url, content_type`,
      [req.user.couple_id, req.user.id, url, req.file.mimetype, req.file.size],
    );
    res.json({ media: rows[0] });
  } catch (e) {
    console.error('media upload', e);
    res.status(500).json({ error: 'server_error' });
  }
});

export default router;
