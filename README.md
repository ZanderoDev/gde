<p align="center">
  <img src="assets/banner.svg" alt="GDE Banner" width="100%">
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License"></a>
  <img src="https://img.shields.io/badge/python-3.8%2B-blue.svg" alt="Python">
  <img src="https://img.shields.io/badge/cipher-ChaCha20--Poly1305-emerald.svg" alt="Cipher">
  <img src="https://img.shields.io/badge/protocol-MCP%20JSON--RPC-cyan.svg" alt="MCP">
  <img src="https://img.shields.io/badge/vault-SQLite%20Local-yellow.svg" alt="Vault">
</p>

# GDE (Google Drive Encryption)

CLI tool buat enkripsi file atau folder secara lokal sebelum di-upload ke Google Drive via MCP (`@piotr-agier/google-drive-mcp`).

Prinsipnya **zero-knowledge**: Google cuma nerima blob ciphertext acak (`gde_<label>.enc`). Kunci enkripsi dan metadata nama asli disimpan aman di vault SQLite lokal kamu (`~/.config/gde/vault.db`). Pihak Google atau siapa pun yang mengakses akun Drive nggak bakal bisa baca isi maupun nama asli filenya.

---

## Cara Kerja

```
[File / Folder Asli]
       │
       ├─ File tunggal : Baca raw bytes langsung (tanpa ZIP)
       └─ Folder       : Kompres otomatis ke format ZIP
       │
       ▼
[Enkripsi ChaCha20-Poly1305]
  • Kunci 256-bit acak unik per file (CSPRNG)
  • Nonce 96-bit unik
  • Label unik (misal: gde_febb82b998aa27ca) di-bind ke AAD (anti-tamper)
       │
       ├─────────────────────────────────────────┐
       ▼                                         ▼
[Vault Lokal]                            [Google Drive]
~/.config/gde/vault.db                   File yang ter-upload:
• Kunci 256-bit                          gde_<label>.enc
• Nama asli                              (Blob biner acak,
• Tipe (File/Folder)                      tanpa metadata asli)
• Google Drive File ID
```

---

## Fitur

- **ChaCha20-Poly1305 (256-bit AEAD)**: Standar IETF RFC 8439. Cepat, ringan di CPU, dan kebal cache-timing attack tanpa butuh akselerasi hardware AES-NI.
- **Kunci Unik per File**: Setiap file dienkripsi dengan kunci 32-byte independen (`secrets.token_bytes(32)`). Tidak ada master key tunggal.
- **Smart Packing**: File tunggal langsung dienkripsi tanpa overhead ZIP. Folder otomatis di-zip rekursif sebelum dienkripsi dengan mempertahankan permission executable (`0755`), direktori read-only (`0555`), symlink (relatif & absolut), dan subfolder kosong. Dilengkapi proteksi Zip Slip.
- **Anti-Tampering**: Label file terikat ke AAD (Additional Authenticated Data). Kalau isi file atau label dimanipulasi, tag Poly1305 langsung menolak dekripsi.
- **Vault Lokal & Backup Kunci**: SQLite lokal disimpan dengan permission ketat (`chmod 600`). Dilengkapi perintah `export-keys` dan `import-keys` untuk backup/migrasi kunci.
- **Deteksi Akses & Peringatan**: File/folder yang tidak dapat dibaca (`PermissionError`) atau file khusus (FIFO/device) dideteksi dan dilaporkan eksplisit (exit code 2 untuk backup parsial kecuali `--force`).
- **Tampilan CLI Rapi**: Output tabel berwarna dengan opsi download interaktif.
- **Native MCP Integration**: Komunikasi langsung ke server Google Drive MCP lewat stdio JSON-RPC (resilient terhadap log stdout).

---

## Requirements

- Linux atau macOS
- Python 3.8+ (dan modul `cryptography`)
- Node.js & npx v18+ (dibutuhkan untuk menjalankan runner GDrive MCP)

---

## Setup Google Drive MCP

GDE memanfaatkan runner MCP dari `@piotr-agier/google-drive-mcp` untuk upload dan download ke Google Drive. Ikuti langkah setup berikut:

### 1. Bikin Project di Google Cloud Console
1. Buka [Google Cloud Console](https://console.cloud.google.com/).
2. Buat project baru (misal: `gde-vault`).

### 2. Aktifkan Google Drive API
1. Buka menu **APIs & Services** > **Library**.
2. Cari **Google Drive API**, lalu klik **Enable**.

### 3. Konfigurasi OAuth Consent Screen
1. Buka **APIs & Services** > **OAuth consent screen**.
2. Pilih User Type **External** lalu klik **Create**.
3. Isi kolom wajib (App name, User support email, Developer contact email).
4. Di bagian **Scopes**, tambahkan scope:
   - `https://www.googleapis.com/auth/drive`
   - `https://www.googleapis.com/auth/drive.file`
5. Di bagian **Test users**, tambahkan email Google yang mau dipakai login.
6. Simpan konfigurasi.

### 4. Bikin OAuth 2.0 Client ID
1. Buka **APIs & Services** > **Credentials**.
2. Klik **Create Credentials** > **OAuth client ID**.
3. Pilih Application type: **Desktop app**.
4. Beri nama (misal: `GDE Client`), lalu klik **Create**.
5. Download file JSON kredensial tersebut.

### 5. Simpan Kredensial MCP
Buat folder konfigurasi MCP dan salin file JSON yang tadi di-download dengan nama `gcp-oauth.keys.json`:

```bash
mkdir -p ~/.config/google-drive-mcp
cp /path/ke/credentials.json ~/.config/google-drive-mcp/gcp-oauth.keys.json
```

Pastikan format isinya seperti ini:
```json
{
  "installed": {
    "client_id": "YOUR_CLIENT_ID.apps.googleusercontent.com",
    "project_id": "your-project-id",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "client_secret": "YOUR_CLIENT_SECRET"
  }
}
```

### 6. Login & Otorisasi Akun
Jalankan perintah ini di terminal:

```bash
npx -y @piotr-agier/google-drive-mcp
```
Browser bakal terbuka untuk konfirmasi izin akses Google Drive. Setelah disetujui, token otomatis tersimpan di `~/.config/google-drive-mcp/tokens.json`.

---

## Instalasi GDE

Clone repo dan jalankan skrip installernya:

```bash
git clone https://github.com/ZanderoDev/gde.git
cd gde
./install.sh
```

Skrip installer otomatis:
- Mengecek Python 3 dan Node.js/npx.
- Menginstall dependensi `cryptography`.
- Memasang binary ke `~/.local/bin/gde` dan symlink `egd`.
- Menjalankan crypto self-test.

> Pastikan `~/.local/bin` sudah terdaftar di `$PATH`. Kalau belum, tambahkan ke `~/.bashrc` atau `~/.zshrc`:
> ```bash
> export PATH="$HOME/.local/bin:$PATH"
> ```

---

## Cara Pakai

### Enkripsi & Upload File Tunggal
```bash
gde dokumen.md
gde database.sqlite
```
File langsung dienkripsi raw bytes (tanpa ZIP), kuncinya masuk ke vault lokal, lalu di-upload ke GDrive sebagai `gde_<label>.enc`.

### Enkripsi & Upload Folder
```bash
gde ~/Dokumen
```
Folder otomatis di-pack ke ZIP secara rekursif, dienkripsi, lalu di-upload ke GDrive.

### List File & Download Interaktif
```bash
gde list
```

Tampilan tabel:
```text
=== DAFTAR FILE ENCRYPTED GOOGLE DRIVE (GDE) ===
No   Nama                      Tipe     Ukuran       GDrive ID            Waktu
-------------------------------------------------------------------------------------
1    Dokumen                   Folder   12.40 MB     1xK9qLm7P_...        2026-10-26 16:30:10
2    dokumen.md                File     4.20 KB      1aZ3pQr8S_...        2026-10-26 18:44:12
-------------------------------------------------------------------------------------

Masukkan No file untuk download & restore (atau 'q' keluar): 2
```
Tinggal ketik nomor filenya. GDE bakal download blob dari GDrive, ambil kunci dari vault lokal, verifikasi integritas, lalu ekstrak/tulis file aslinya ke direktori kerja saat ini.

### Download Langsung (Non-interaktif)
Bisa langsung panggil pakai Nomor ID atau Label:
```bash
gde download 1
# atau
gde download gde_febb82b998aa27ca
```

### Backup Berjadwal Otomatis (`--time` / `-t`)
Jalankan backup otomatis secara berkala untuk folder atau file. GDE akan mengeksekusi siklus pertama segera, lalu otomatis mengulang proses backup sesuai interval waktu yang ditentukan.

Format durasi waktu mendukung:
- `s` : detik (seconds)
- `m` : menit (minutes)
- `h` : jam (hours)
- `d` : hari (days)
- `y` : tahun (years)

Bisa juga menggunakan kombinasi (misalnya `1d12h` atau `1h30m`).

```bash
# Backup folder Dokumen ke Google Drive otomatis setiap 24 jam
gde ~/Dokumen --time 24h

# Backup folder ke Google Drive setiap 7 hari
gde ~/Dokumen -t 7d

# Backup folder ke Google Drive setiap 1 tahun
gde ~/ArsipTahunan --time 1y

# Backup mode lokal setiap 12 jam
gde --local ~/Dokumen -t 12h

# Testing interval cepat (misal: setiap 30 detik)
gde ~/Dokumen --time 30s
```
> Tekan `Ctrl+C` kapan saja untuk menghentikan penjadwal backup.

### Mode Offline / Enkripsi Lokal Saja
Kalau cuma mau enkripsi lokal tanpa upload ke GDrive:
```bash
gde --local rahasia.txt
```
File terenkripsi disimpan langsung di folder aktif sebagai `rahasia.txt.enc`.

### Dekripsi File Lokal
Untuk mendekripsi kembali file `.enc` yang ada di mesin:
```bash
gde decrypt rahasia.txt.enc
```
GDE otomatis membaca label di header file, mengambil kunci yang cocok dari vault lokal, dan memulihkan file/folder aslinya.

### Backup & Restore Kunci Vault
Semua kunci tersimpan di database lokal `vault.db`. Anda bisa mengekspor daftar kunci ke file JSON cadangan (dibuat dengan izin ketat `chmod 600`):
```bash
# Export semua kunci vault ke file JSON (disimpan atomic 0600)
gde export-keys cadangan-kunci.json

# Import kunci dari file backup JSON ke mesin baru
gde import-keys cadangan-kunci.json
```
> **Catatan:** File export berisi kunci plaintext. Pastikan disimpan di media penyimpanan yang aman (misalnya drive terenkripsi/LUKS).

### Pengaturan Bahasa / Language Settings (`set-lang` & `--lang`)
GDE mendukung dua bahasa: **Bahasa Indonesia (ID)** dan **English (EN)**.

Saat pertama kali menjalankan `./install.sh`, installer akan menawarkan pilihan bahasa instalasi dan menyimpannya ke konfigurasi lokal. Anda juga bisa mengganti bahasa kapan saja:
```bash
# Ubah bahasa tampilan default ke English
gde set-lang en

# Ubah kembali ke Bahasa Indonesia
gde set-lang id

# Override bahasa per-perintah
gde --lang en list
```

### Opsi Tambahan

#### 1. Penimpaan File Otomatis (`--force` / `-f`)
Secara default, GDE meminta konfirmasi `[y/N]` sebelum menimpa file atau folder yang sudah ada di disk. Untuk eksekusi otomatis tanpa prompt (misal di script atau cron), sertakan flag `--force` atau `-f`:
```bash
gde download 1 --force
gde decrypt dokumen.md.enc -f
```

#### 2. Abaikan Berkas Tak Terbaca (`--allow-partial`)
Jika sebuah folder berisi file atau subdirektori yang tidak bisa dibaca (misalnya izin `000` atau milik root), GDE akan menampilkan daftar file tersebut dan berhenti dengan **exit code 2** (agar script/cron tahu backup tidak 100% lengkap).
Untuk tetap memproses dan mengabaikan entri yang tak terbaca (exit code 0):
```bash
gde ~/Proyek --allow-partial
```

### Jalankan Self-Test
Buat ngecek fungsi enkripsi, permission zip, dan deteksi tampering di sistem kamu:
```bash
gde test
```

---

## Format Biner File (`.enc`)

```
+---------------+-------------------+---------------------+----------------+--------------------+----------------+
|  MAGIC (4B)   | Label_Len (1 Byte)|  Label ID (N Bytes) | Nonce (12 Byte)| Ciphertext (VarLen)| Auth Tag (16B) |
|    "GDE1"     |        0x10       | "gde_febb82b998..." |  Random Bytes  |   Encrypted Data   |  Poly1305 MAC  |
+---------------+-------------------+---------------------+----------------+--------------------+----------------+
```

---

## Troubleshooting

- **Error token revoked/expired:**
  Jalankan ulang otorisasi akun:
  ```bash
  npx -y @piotr-agier/google-drive-mcp auth
  ```
- **Command `gde` tidak ditemukan:**
  Tambahkan path bin lokal ke konfigurasi shell:
  ```bash
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
  ```
- **Error modul `cryptography`:**
  Install modul via pip:
  ```bash
  pip3 install --user cryptography
  ```

---

## Lisensi

[MIT License](LICENSE) © 2026 ZanderoDev
