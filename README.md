# GDE - Google Drive Encryption 🔐

**GDE** (*Google Drive Encryption*) adalah CLI tool enkripsi lokal zero-knowledge kelas militer yang terintegrasi langsung dengan **Google Drive MCP** (`@piotr-agier/google-drive-mcp`).

Dengan GDE, **Google tidak pernah melihat file asli Anda**. Data dienkripsi secara lokal menggunakan **ChaCha20-Poly1305 (256-bit AEAD)** sebelum dikirim ke Google Drive. Setiap file memiliki kunci enkripsi acak unik tersendiri yang disimpan aman di vault SQLite lokal Anda.

---

## 📑 Daftar Isi

- [Arsitektur & Cara Kerja](#-arsitektur--cara-kerja)
- [Fitur Utama](#-fitur-utama)
- [Prasyarat Sistem](#-prasyarat-sistem)
- [Panduan Setup Google Drive MCP](#-panduan-setup-google-drive-mcp)
- [Instalasi GDE](#-instalasi-gde)
- [Panduan Penggunaan](#-panduan-penggunaan)
- [Spesifikasi Keamanan](#-spesifikasi-keamanan)
- [Troubleshooting](#-troubleshooting)
- [Lisensi](#-lisensi)

---

## 🧠 Arsitektur & Cara Kerja

```
[File / Dokumen Asli]
       │
       ├─ Jika File Tunggal : Baca byte mentah langsung (tanpa ZIP)
       └─ Jika Folder       : Kompres otomatis ke format ZIP
       │
       ▼
[Enkripsi Lokal ChaCha20-Poly1305]
  • Kunci 256-bit acak unik per file (CSPRNG)
  • Nonce 96-bit unik
  • Label acak unik (misal: gde_febb82b998aa27ca)
  • Label di-bind ke Additional Authenticated Data (AAD) anti-tamper
       │
       ├─────────────────────────────────────────┐
       ▼                                         ▼
[Database Lokal]                         [Google Drive]
~/.config/gde/vault.db                   Hanya menerima file:
• Kunci 256-bit                          gde_<label>.enc
• Nama Asli                              (Blob biner acak,
• Tipe (File/Folder)                      Google tidak bisa baca)
• Google Drive File ID
```

### Keunggulan Zero-Knowledge
1. **Google Drive hanya melihat blob biner acak** bernama `gde_<label>.enc`.
2. Nama file asli, ekstensi, struktur folder, dan isi file **100% tersembunyi**.
3. Kunci enkripsi tidak pernah diunggah ke cloud.

---

## ✨ Fitur Utama

- 🛡️ **Kriptografi Kelas Militer**: Menggunakan cipher ChaCha20-Poly1305 (IETF RFC 8439), kebal terhadap *cache-timing attacks*, dan sangat ringan di CPU tanpa perlu hardware AES-NI.
- 🔑 **Setiap File Beda Kunci**: Kunci 32-byte (256-bit) di-generate secara independen via `secrets.token_bytes(32)`.
- ⚡ **Smart Packing**: File tunggal (`file.md`, `laporan.pdf`, dsb.) langsung dienkripsi tanpa overhead ZIP. Folder otomatis dikompres ke ZIP sebelum dienkripsi.
- 🔏 **Anti-Tampering**: Poly1305 MAC tag otomatis menolak dekripsi jika ada manipulasi data (bahkan jika hanya 1 bit berubah).
- 🗄️ **Vault SQLite Terisolasi**: Metadata dan kunci disimpan di `~/.config/gde/vault.db` dengan permission ketat (`chmod 600`).
- 🎨 **Terminal UI Interaktif**: Tampilan tabel berwarna, mudah memilih file yang ingin diunduh dan dipulihkan.
- 🔌 **Integrasi Asli MCP**: Berkomunikasi langsung dengan server Google Drive MCP melalui stdio JSON-RPC.

---

## 📋 Prasyarat Sistem

- **Sistem Operasi**: Linux / macOS
- **Python**: Versi 3.8 ke atas (dengan pustaka `cryptography`)
- **Node.js & npx**: Versi 18 ke atas (diperlukan untuk menjalankan Google Drive MCP)

---

## 🛠️ Panduan Setup Google Drive MCP

Agar GDE dapat mengunggah dan mengunduh file secara otomatis ke Google Drive, Anda perlu mengonfigurasi kredensial OAuth Google Cloud untuk **Google Drive MCP**.

### Langkah 1: Buat Project di Google Cloud Console
1. Buka [Google Cloud Console](https://console.cloud.google.com/).
2. Buat project baru (misalnya diberi nama `GDrive-MCP-Vault`).

### Langkah 2: Aktifkan Google Drive API
1. Masuk ke menu **APIs & Services** > **Library**.
2. Cari **Google Drive API**, lalu klik **Enable**.

### Langkah 3: Konfigurasi OAuth Consent Screen
1. Masuk ke **APIs & Services** > **OAuth consent screen**.
2. Pilih User Type **External** lalu klik **Create**.
3. Isi informasi wajib (App name, User support email, Developer contact email).
4. Pada bagian **Scopes**, tambahkan scope:
   - `.../auth/drive`
   - `.../auth/drive.file`
5. Pada bagian **Test users**, tambahkan alamat email Google yang akan Anda gunakan untuk login.
6. Simpan konfigurasi.

### Langkah 4: Buat OAuth 2.0 Client ID
1. Masuk ke **APIs & Services** > **Credentials**.
2. Klik **+ Create Credentials** > **OAuth client ID**.
3. Pilih Application type: **Desktop app**.
4. Beri nama, misalnya `GDE Desktop Client`, lalu klik **Create**.
5. Klik tombol **Download JSON** pada kredensial yang baru dibuat.

### Langkah 5: Simpan Kredensial ke Direktori MCP
Buat folder konfigurasi MCP di komputer Anda dan letakkan file kredensial JSON tersebut dengan nama `gcp-oauth.keys.json`:

```bash
mkdir -p ~/.config/google-drive-mcp
cp /path/ke/file-download-credentials.json ~/.config/google-drive-mcp/gcp-oauth.keys.json
```

Format isi `~/.config/google-drive-mcp/gcp-oauth.keys.json` harus berbentuk:
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

### Langkah 6: Otorisasi Awal Akun Google
Jalankan perintah berikut di terminal Anda untuk menghubungkan akun Google pertama kali:

```bash
npx -y @piotr-agier/google-drive-mcp
```
Browser akan terbuka otomatis untuk meminta persetujuan akses Google Drive. Setelah disetujui, token akan tersimpan di `~/.config/google-drive-mcp/tokens.json`.

---

## 🚀 Instalasi GDE

1. Clone repositori ini:
   ```bash
   git clone https://github.com/ZanderoDev/gde.git
   cd gde
   ```

2. Jalankan skrip instalasi otomatis:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

Skrip installer akan:
- Memeriksa ketersediaan Python 3 dan Node.js/npx.
- Memasang paket python `cryptography`.
- Memasang executable `gde` ke `~/.local/bin/gde`.
- Menjalankan internal crypto self-test untuk memastikan algoritma berjalan normal.

> **Catatan:** Pastikan `~/.local/bin` sudah ada di `$PATH` shell Anda. Jika belum, tambahkan ke `~/.bashrc` atau `~/.zshrc`:
> ```bash
> export PATH="$HOME/.local/bin:$PATH"
> ```

---

## 💻 Panduan Penggunaan

### 1. Enkripsi & Upload File Tunggal (Tanpa ZIP)
```bash
gde dokumen.md
gde rahasia.pdf
```
File akan langsung dienkripsi byte mentahnya, disimpan metadata kuncinya ke vault lokal, dan diunggah ke Google Drive sebagai `gde_<label>.enc`.

### 2. Enkripsi & Upload Folder (Otomatis ZIP)
```bash
gde ~/DokumenPribadi
```
Folder akan dikompresi ke format ZIP di memori/temp, dienkripsi penuh, lalu diunggah ke Google Drive.

### 3. List File & Unduh Interaktif
```bash
gde list
```
Contoh tampilan:
```text
=== DAFTAR FILE ENCRYPTED GOOGLE DRIVE (GDE) ===
No   Nama                      Tipe     Ukuran       GDrive ID            Waktu
-------------------------------------------------------------------------------------
1    DokumenPribadi            Folder   12.40 MB     1xK9qLm7P_...        2026-10-26 16:30:10
2    dokumen.md                File     4.20 KB      1aZ3pQr8S_...        2026-10-26 18:44:12
-------------------------------------------------------------------------------------

Masukkan No file untuk download & restore (atau 'q' keluar): 2
```
GDE akan:
1. Mengunduh file terenkripsi dari Google Drive via MCP.
2. Mengambil kunci 256-bit yang cocok dari database lokal.
3. Memverifikasi integritas tag Poly1305.
4. Mendekripsi dan merestore kembali ke bentuk file/folder aslinya.

### 4. Unduh & Pulihkan Langsung (Non-interaktif)
Anda juga bisa langsung memulihkan file dengan menyertakan Nomor ID atau Label:
```bash
gde download 1
# atau
gde download gde_febb82b998aa27ca
```

### 5. Mode Enkripsi Lokal (Tanpa Internet / Tanpa Upload)
Gunakan flag `--local` jika hanya ingin mengenkripsi dan menyimpan kunci ke vault lokal tanpa mengunggah ke Google Drive:
```bash
gde --local data-sensitif.txt
```

### 6. Jalankan Verifikasi Self-Test
Untuk memastikan fungsi enkripsi, integritas data, dan deteksi tampering bekerja sempurna di mesin Anda:
```bash
gde test
```

---

## 🔒 Spesifikasi Keamanan

### Format File Terenkripsi (`.enc`)
```
+---------------+-------------------+---------------------+----------------+--------------------+----------------+
|  MAGIC (4B)   | Label_Len (1 Byte)|  Label ID (N Bytes) | Nonce (12 Byte)| Ciphertext (VarLen)| Auth Tag (16B) |
|    "GDE1"     |        0x10       | "gde_febb82b998..." |  Random Bytes  |   Encrypted Data   |  Poly1305 MAC  |
+---------------+-------------------+---------------------+----------------+--------------------+----------------+
```

- **Cipher**: ChaCha20 Stream Cipher dengan 256-bit key.
- **Autentikasi**: Poly1305 128-bit MAC.
- **AAD (Additional Authenticated Data)**: Label file di-bind ke AAD. Mengubah label pada header file akan menyebabkan verifikasi Poly1305 gagal, melindungi file dari *label-spoofing* atau pertukaran file jahat.
- **Database Vault**: SQLite lokal diatur dengan `chmod 600` (hanya user pemilik OS yang dapat membaca dan menulis).

---

## ❓ Troubleshooting

#### 1. Error: `Account 'default' authorization was revoked or has expired`
Token OAuth Anda di Google Drive telah kedaluwarsa atau dicabut. Jalankan kembali perintah otorisasi:
```bash
npx -y @piotr-agier/google-drive-mcp
```
Browser akan meminta login ulang dan memperbarui file token di `~/.config/google-drive-mcp/tokens.json`.

#### 2. Perintah `gde` tidak ditemukan
Pastikan direktori `~/.local/bin` ada di variabel lingkungan `$PATH`.
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

#### 3. Error: `No module named 'cryptography'`
Install pustaka `cryptography` via pip:
```bash
pip3 install --user cryptography
```

---

## 📄 Lisensi

Proyek ini dilisensikan di bawah lisensi **MIT License** - lihat file [LICENSE](LICENSE) untuk detail selengkapnya.

Dibuat dengan ❤️ oleh [ZanderoDev](https://github.com/ZanderoDev).
