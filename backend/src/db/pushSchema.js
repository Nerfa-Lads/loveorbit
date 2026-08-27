import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import 'dotenv/config';
import pg from 'pg';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const schemaPath = path.resolve(__dirname, '../../db/schema.sql');

const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.DATABASE_URL && process.env.DATABASE_URL.includes('sslmode=require')
    ? { rejectUnauthorized: true }
    : undefined,
});

async function main() {
  if (!process.env.DATABASE_URL) {
    console.error('DATABASE_URL not set. Copy .env.example to .env and fill it in.');
    process.exit(1);
  }
  const sql = fs.readFileSync(schemaPath, 'utf8');
  console.log('[db:push] applying schema.sql to', process.env.DATABASE_URL.replace(/:[^:@]+@/, ':****@'));
  await pool.query(sql);
  console.log('[db:push] done.');
  await pool.end();
}

main().catch((e) => {
  console.error('[db:push] failed:', e);
  process.exit(1);
});
