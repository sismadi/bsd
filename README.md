# Basadi – Bank Sampah Digital

Aplikasi web (PWA-ready, mobile-first) untuk setor sampah, saldo, penukaran, lokasi TPS, edukasi dan notifikasi.
Peran: **Nasabah**, **Admin TPS**, **Super Admin** (sesuai proposal BSD).

## Arsitektur

```
GitHub ──(Workers Builds)──▶ Cloudflare Worker "bsd"
                              ├─ public/            Frontend: HTML + CSS + JS (aset statis Cloudflare)
                              ├─ src/worker.js      Gateway backend: sesi, role, CSRF, routing
                              │   └─ src/services/  auth · setoran · penukaran · dompet · master
                              └─ D1 (SQLite)        binding DB  ← schema.sql
Rahasia & env: Cloudflare (secret SESSION_SECRET, CAPTCHA_SECRET; vars di wrangler.toml)
```

- **Frontend** dan **backend** terpisah tegas: frontend hanya bicara lewat `/api/*` (`public/js/api.js`).
- Tiap **service** hanya mendaftarkan route ke router → bisa dipecah menjadi Worker sendiri (service binding) tanpa mengubah logika.
- **DRY**: satu `validate()`, satu `crud()` factory (jenis sampah/TPS/edukasi), satu `formHtml()`, satu `api`, menu digerakkan tabel `ROUTES`.

## Keamanan
- Captcha penjumlahan stateless: jawaban tidak pernah dikirim ke browser (HMAC dengan `CAPTCHA_SECRET`), kedaluwarsa 5 menit, sekali pakai (tabel `captcha_used`).
- Sesi: cookie `HttpOnly; Secure; SameSite=Strict` berisi token HMAC (`SESSION_SECRET`); akun dimuat ulang dari D1 tiap request.
- PIN di-hash PBKDF2-SHA256 (bukan PIN polos seperti di `kepik.sql`).
- Saldo **dihitung** dari transaksi (tidak disimpan) dan penukaran dibuat atomik → tidak bisa tarik ganda.
- Header CSP ketat (`public/_headers`), cek Origin untuk request tulis, semua query memakai bind.

## Setup (sekali)
```bash
npm install
npx wrangler login
npx wrangler d1 create bsd            # salin database_id ke wrangler.toml
npm run db:schema && npm run db:seed        # buat tabel + data contoh
npx wrangler secret put SESSION_SECRET      # isi string acak panjang (mis. openssl rand -hex 32)
npx wrangler secret put CAPTCHA_SECRET      # string acak lain
node scripts/make-admin.mjs 0812xxxxxxxx "Nama Anda" 123456 > admin.sql
npx wrangler d1 execute bsd --remote --file=admin.sql   # super admin pertama
npm run deploy
```
Lokal: salin `.dev.vars.example` → `.dev.vars`, lalu `npm run db:local && npm run dev`.

## Hubungkan GitHub → Cloudflare
1. `git init && git add . && git commit -m "Basadi" && git remote add origin <repo> && git push -u origin main`
2. Cloudflare Dashboard → **Workers & Pages → Create → Import a repository** → pilih repo.
3. Deploy command: `npx wrangler deploy` (build command dikosongkan). Setiap `git push` ke `main` otomatis deploy.
4. Pastikan secret ada di **Settings → Variables and Secrets** milik Worker (bukan di repo).

## Catatan
- Login memakai **No HP + PIN + captcha**. OTP (sesuai proposal) butuh gateway SMS/WhatsApp berbayar; titik pasangnya `src/services/auth.js`.
- Foto setoran dikompres di perangkat lalu disimpan di D1. Untuk volume besar pindahkan ke R2.
- Pembayaran DANA/OVO/GoPay dicatat dan diproses manual oleh admin; integrasi payout API bisa ditambah di `services/penukaran.js`.
- Untuk captcha yang lebih kuat, ganti `lib/captcha.js` dengan Cloudflare Turnstile (antarmuka `issue/check` tetap sama).
- Aktifkan Cloudflare Rate Limiting pada `/api/auth/*`.

## Demo 3 peran
```bash
npm run demo          # buat akun demo + contoh transaksi (aman diulang = reset)
npm run demo:clean    # hapus semua data demo
```
| Peran | No HP | PIN |
|---|---|---|
| Admin | 08990000001 | 123456 |
| Petugas (TPS Bank Sampah Cinta) | 08990000002 | 123456 |
| Pengguna | 08990000003 | 123456 |

**Jangan biarkan akun demo aktif di produksi** – jalankan `npm run demo:clean` sebelum dipakai sungguhan.
