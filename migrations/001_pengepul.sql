-- Migrasi untuk database LAMA: izinkan role 'pengepul' pada users.
-- SQLite tidak bisa mengubah CHECK, jadi tabel users dibangun ulang (data tetap). Urutan:
--   1) wrangler d1 execute bsd --remote --file=migrations/001_pengepul.sql
--   2) wrangler d1 execute bsd --remote --file=schema.sql      (membuat penjualan, delegasi, indeks)
--   3) wrangler d1 execute bsd --remote --file=seed.sql        (opsional: kategori baru)
-- Database baru TIDAK perlu file ini (schema.sql sudah memuatnya). Sebaiknya ekspor cadangan dulu:
--   wrangler d1 export bsd --remote --output=backup.sql
PRAGMA defer_foreign_keys = true;
-- notifikasi ON DELETE CASCADE ke users -> cadangkan agar tidak ikut terhapus saat users diganti.
CREATE TABLE _notif_bak AS SELECT * FROM notifikasi;
CREATE TABLE _users_bak AS SELECT * FROM users;
DROP TABLE users;
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  no_hp TEXT NOT NULL UNIQUE,
  nama TEXT NOT NULL,
  pin_hash TEXT NOT NULL,                       -- PBKDF2-SHA256, bukan PIN polos
  role TEXT NOT NULL DEFAULT 'nasabah' CHECK (role IN ('nasabah','admin_tps','pengepul','super_admin')),
  tps_id INTEGER REFERENCES tps(id) ON DELETE SET NULL,
  aktif INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
INSERT INTO users(id,no_hp,nama,pin_hash,role,tps_id,aktif,created_at)
  SELECT id,no_hp,nama,pin_hash,role,tps_id,aktif,created_at FROM _users_bak;
INSERT OR IGNORE INTO notifikasi(id,user_id,judul,isi,dibaca,created_at)
  SELECT id,user_id,judul,isi,dibaca,created_at FROM _notif_bak;
DROP TABLE _users_bak;
DROP TABLE _notif_bak;
