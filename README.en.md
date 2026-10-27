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

<p align="center">
  <a href="README.md">🇮🇩 Bahasa Indonesia</a> | <b>🇬🇧 English</b>
</p>

# GDE (Google Drive Encryption)

A CLI tool for encrypting files and directories locally before uploading them to Google Drive via MCP (`@piotr-agier/google-drive-mcp`).

Built on **zero-knowledge** principles: Google only receives random ciphertext blobs (`gde_<label>.enc`). Encryption keys and original file metadata stay in your local SQLite vault (`~/.config/gde/vault.db`). Neither Google nor anyone with access to your Google Drive account can read your file contents or original filenames.

---

## How It Works

```
[Original File / Directory]
       │
       ├─ Single file : Direct raw bytes encryption (no ZIP overhead)
       └─ Directory   : Auto-compressed to ZIP archive
       │
       ▼
[ChaCha20-Poly1305 Encryption]
  • Unique random 256-bit key per file (CSPRNG)
  • Unique 96-bit nonce
  • Unique label (e.g., gde_febb82b998aa27ca) bound to AAD (tamper-proof)
       │
       ├─────────────────────────────────────────┐
       ▼                                         ▼
[Local Vault]                            [Google Drive]
~/.config/gde/vault.db                   Uploaded file:
• 256-bit key                            gde_<label>.enc
• Original name                          (Random binary blob,
• Type (File/Directory)                  no plaintext metadata)
• Google Drive File ID
```

---

## Features

- **ChaCha20-Poly1305 (256-bit AEAD)**: IETF RFC 8439 standard. Fast, lightweight on CPU, and immune to cache-timing attacks without requiring hardware AES-NI acceleration.
- **Unique Key Per File**: Every file is encrypted with an independent 32-byte key (`secrets.token_bytes(32)`). No single master key.
- **Smart Packing**: Single files are encrypted directly without ZIP overhead. Directories are automatically zipped recursively before encryption, fully preserving executable permissions (`0755`), read-only folders (`0555`), symlinks (relative & absolute), and empty subdirectories. Hardened with Zip Slip protection.
- **Anti-Tampering**: File labels are bound to AAD (Additional Authenticated Data). Any manipulation of ciphertext or label header causes Poly1305 verification to fail and reject decryption.
- **Local Vault & Key Backup**: Local SQLite database stored with strict permissions (`chmod 600`). Includes `export-keys` and `import-keys` commands for key backup and migration.
- **Access Detection & Warnings**: Unreadable files (`PermissionError`) and special devices (FIFOs, sockets) are detected and explicitly reported (exit code 2 on partial backup unless `--force` / `--allow-partial`).
- **Clean CLI Interface**: Formatted colored tables with interactive download prompts.
- **Built-in MCP Server for AI Agents**: Full Model Context Protocol (`2024-11-05`) support via stdio JSON-RPC. AI agents (Claude Desktop, Cursor, Antigravity, Cline) can directly manage encryption, decryption, downloads, and vault status.
- **Native MCP Integration**: Direct stdio JSON-RPC communication with upstream Google Drive MCP runner (resilient against stdout log pollution).

---

## Requirements

- Linux or macOS
- Python 3.8+ (with `cryptography` module)
- Node.js & npx v18+ (needed to execute the Google Drive MCP runner)

---

## Setup Google Drive MCP

GDE relies on the MCP runner from `@piotr-agier/google-drive-mcp` to upload and download files to Google Drive. The steps below follow the [official package setup guide](https://github.com/piotr-agier/google-drive-mcp/blob/master/docs/setup.md).

### 1. Create a Google Cloud Project

1. Open the [Google Cloud Console](https://console.cloud.google.com/).
2. Click **Select a project** > **New Project**.
3. Name your project (e.g., `gde-vault`) and create it.

### 2. Enable Required APIs

1. Go to **APIs & Services** > **Library**.
2. Search for and **Enable** each of the following 5 APIs:
   - **Google Drive API**
   - **Google Docs API**
   - **Google Sheets API**
   - **Google Slides API**
   - **Google Calendar API**
3. Wait for each API to finish activating before proceeding.

### 3. Configure OAuth Consent Screen

1. Go to **APIs & Services** > **OAuth consent screen**.
2. Under **Branding**, fill in the required fields:
   - App name: e.g., `GDE Vault MCP`
   - User support email: your Google email
   - Developer contact email: your Google email
3. Under **Audience**:
   - Select **External** (or **Internal** if using Google Workspace).
   - Add your Google account to the **Test users** list (required while in Testing status).
4. Under **Data Access**, add the recommended scopes:
   - `https://www.googleapis.com/auth/drive.file`
   - `https://www.googleapis.com/auth/documents`
   - `https://www.googleapis.com/auth/spreadsheets`
   - `https://www.googleapis.com/auth/presentations`
   - `https://www.googleapis.com/auth/drive`
   - `https://www.googleapis.com/auth/drive.readonly`
   - `https://www.googleapis.com/auth/calendar`
   - `https://www.googleapis.com/auth/calendar.events`
5. Save your configuration.

> **Tip for Long-Lived Tokens (Avoid 7-Day Expiration):**
> Google enforces a policy where apps with **Testing** status have refresh tokens that expire after 7 days. To prevent having to re-authenticate weekly, click **"Publish App"** on the OAuth consent screen to change its status to **In production**. For personal use, Google verification is not required.

### 4. Create OAuth 2.0 Client ID

1. Go to **APIs & Services** > **Credentials**.
2. Click **Create Credentials** > **OAuth client ID**.
3. Select Application type: **Desktop app** (crucial!).
   > **Why Desktop app?** This type automatically allows loopback redirect callbacks to `http://127.0.0.1:<port>/oauth2callback` without registering redirect URIs manually. Selecting *Web application* will cause authentication to fail with a `redirect_uri_mismatch` error.
4. Name it (e.g., `GDE Client`), then click **Create**.
5. Download the credentials JSON file.

Only the Client ID is required; a client secret is not necessary. Use the downloaded JSON file as-is without manual modifications.

### 5. Save MCP Credentials

The server looks for a file named `gcp-oauth.keys.json`. Create the config directory and copy your downloaded JSON file there:

```bash
mkdir -p ~/.config/google-drive-mcp
cp /path/to/credentials.json ~/.config/google-drive-mcp/gcp-oauth.keys.json
```

The server checks for credentials in the following order:

1. Path specified in the `GOOGLE_DRIVE_OAUTH_CREDENTIALS` environment variable (if set).
2. `~/.config/google-drive-mcp/gcp-oauth.keys.json` (recommended; `XDG_CONFIG_HOME` replaces `~/.config` if set).
3. Project root directory (legacy fallback; unreliable with `npx`).

If the file is not found in any of these locations, the server stops with `OAuth credentials not found`.

### 6. Login and Authenticate

Run the authentication flow in your terminal:

```bash
npx -y @piotr-agier/google-drive-mcp auth
```

Your web browser will open automatically asking for Google Drive permissions. Once approved, the token is saved to `~/.config/google-drive-mcp/tokens.json` with secure permissions (`0600`).

> - **Port Conflict?** By default, the server tries ports `3000–3004`. If those are in use (e.g., local React/Vite dev server), specify a different starting port via: `export GOOGLE_DRIVE_MCP_AUTH_PORT=3100`.
> - **Never commit** credential files (`gcp-oauth.keys.json`) or `tokens.json` to any public repository.

---

## Installation

Clone the repository and run the installer:

```bash
git clone https://github.com/ZanderoDev/gde.git
cd gde
./install.sh --lang=en
```

The installer script automatically:

- Checks for Python 3 and Node.js/npx.
- Installs the `cryptography` Python dependency.
- Installs the binary to `~/.local/bin/gde` and creates a symlink `egd`.
- Runs internal cryptographic self-tests.

> Ensure `~/.local/bin` is in your `$PATH`. If not, add it to `~/.bashrc` or `~/.zshrc`:
>
> ```bash
> export PATH="$HOME/.local/bin:$PATH"
> ```

---

## Usage

### Encrypt & Upload Single File

```bash
gde document.md
gde database.sqlite
```

The file is encrypted directly from raw bytes (without ZIP overhead), the key is stored in your local vault, and the file is uploaded to Google Drive as `gde_<label>.enc`.

### Encrypt & Upload Directory

```bash
gde ~/Documents
```

The directory is automatically compressed into a ZIP archive recursively, encrypted, and uploaded to Google Drive.

### List Files & Interactive Download

```bash
gde list
```

Table output:

```text
=== GOOGLE DRIVE ENCRYPTED FILES (GDE) ===
No   Name                      Type     Size         GDrive ID            Time
-------------------------------------------------------------------------------------
1    Documents                 Folder   12.40 MB     1xK9qLm7P_...        2026-10-26 16:30:10
2    document.md               File     4.20 KB      1aZ3pQr8S_...        2026-10-26 18:44:12
-------------------------------------------------------------------------------------

Enter file No to download & restore (or 'q' to quit): 2
```

Simply type the file number. GDE downloads the ciphertext blob from Google Drive, retrieves the decryption key from the local vault, verifies cryptographic integrity, and restores the original file to your current working directory.

### Direct Download (Non-interactive)

Download directly by Vault ID number or file label:

```bash
gde download 1
# or
gde download gde_febb82b998aa27ca
```

### Scheduled Automatic Backup (`--time` / `-t`)

Schedule automated recurring backups for files or directories. GDE runs the first cycle immediately, then repeats automatically according to your specified interval.

Supported duration units:

- `s`: seconds
- `m`: minutes
- `h`: hours
- `d`: days
- `y`: years

Combinations are also supported (e.g., `1d12h` or `1h30m`).

```bash
# Backup Documents folder to Google Drive every 24 hours
gde ~/Documents --time 24h

# Backup folder to Google Drive every 7 days
gde ~/Documents -t 7d

# Backup folder to Google Drive once a year
gde ~/YearlyArchive --time 1y

# Local-only backup every 12 hours
gde --local ~/Documents -t 12h

# Rapid testing interval (e.g., every 30 seconds)
gde ~/Documents --time 30s
```

> Press `Ctrl+C` at any time to gracefully stop the scheduled backup runner.

### Offline Mode / Local Encryption Only

If you only want local encryption without uploading to Google Drive:

```bash
gde --local secret.txt
```

The encrypted file is saved in the current directory as `secret.txt.enc`.

### Decrypt Local File

To decrypt an `.enc` file stored locally:

```bash
gde decrypt secret.txt.enc
```

GDE reads the label header, matches the key from your local vault, and restores the original file or directory.

### Backup & Restore Vault Keys

All encryption keys are stored in the local `vault.db` SQLite database. You can export keys to a backup JSON file (created with secure permissions `chmod 600`):

```bash
# Export all vault keys to a JSON file (atomic 0600)
gde export-keys keys-backup.json

# Import vault keys from a backup JSON file on a new machine
gde import-keys keys-backup.json
```

> **Note:** The export file contains plaintext encryption keys. Store it on secure encrypted storage (e.g., LUKS volume).

### Language Configuration (`set-lang` & `--lang`)

GDE provides bilingual support: **Bahasa Indonesia (ID)** and **English (EN)**.

During the first run of `./install.sh`, you can choose your preferred interface language. You can also change it at any time:

```bash
# Switch default language to English
gde set-lang en

# Switch default language to Indonesian
gde set-lang id

# Override language for a single command execution
gde --lang en list
```

### AI Agent Integration via MCP (Model Context Protocol)

GDE includes a built-in Model Context Protocol server via stdio JSON-RPC 2.0 (`gde mcp`). This allows AI assistants and coding agents (Claude Desktop, Cursor, Antigravity, Cline, Windsurf) to access encryption, decryption, and Google Drive vault management directly as **native tools**.

#### 1. Claude Desktop Configuration (`claude_desktop_config.json`)

Add the following block to your Claude Desktop configuration file (`~/.config/Claude/claude_desktop_config.json` on Linux, or `~/Library/Application Support/Claude/claude_desktop_config.json` on macOS):

```json
{
  "mcpServers": {
    "gde": {
      "command": "gde",
      "args": ["mcp"]
    }
  }
}
```

> If `gde` is installed in a custom location, provide its full path (e.g., `"/home/username/.local/bin/gde"`).

#### 2. Cursor / Generic MCP Client Configuration

In Cursor, navigate to Settings > Features > MCP Servers, and add a new server:

- **Type**: `command`
- **Command**: `gde mcp`

#### 3. Available Tools for AI Agents

| Tool Name | Description | Key Arguments |
|---|---|---|
| `gde_encrypt` | Encrypt a file/folder using ChaCha20-Poly1305. Can upload to GDrive or save locally. | `path` (string, required), `local_only` (bool), `allow_partial` (bool) |
| `gde_decrypt` | Decrypt a local `.enc` file using keys from the local SQLite vault. | `enc_path` (string, required), `dest_dir` (string), `force` (bool), `key_hex` (string) |
| `gde_list` | List all encrypted files and directories stored in the vault. | *(no arguments)* |
| `gde_download` | Download encrypted file from Google Drive (or locate locally) and restore to disk. | `item_id_or_label` (string, required), `dest_dir` (string), `force` (bool) |
| `gde_status` | Check GDE status: vault directory, entry count, and Google Drive token connection. | *(no arguments)* |
| `gde_export_keys` | Export all vault encryption keys to a secure JSON backup (mode `0600`). | `out_path` (string, optional) |
| `gde_import_keys` | Import vault encryption keys from a backup JSON file with traversal sanitization. | `in_path` (string, required) |

Example prompts for AI agents:

- *"Please securely encrypt this project folder using the gde_encrypt tool with local_only."*
- *"Check if there are any recent backup entries in the vault with gde_list."*
- *"Decrypt the file report.pdf.enc into the ./restored folder."*

---

### Additional Options

#### 1. Automatic File Overwrite (`--force` / `-f`)

By default, GDE prompts for confirmation `[y/N]` before overwriting an existing destination file or folder. For automated scripts or cron jobs, supply `--force` or `-f`:

```bash
gde download 1 --force
gde decrypt document.md.enc -f
```

#### 2. Skip Unreadable Files (`--allow-partial`)

If a folder contains unreadable files or directories (e.g., permission `000` or root-owned), GDE warns and exits with **exit code 2** so scripts recognize incomplete backups. To skip unreadable entries and complete with exit code 0:

```bash
gde ~/Project --allow-partial
```

### Run Self-Test

To verify cipher integrity, permissions preservation, and tamper detection on your machine:

```bash
gde test
```

---

## Encrypted File Binary Format (`.enc`)

```
+---------------+-------------------+---------------------+----------------+--------------------+----------------+
|  MAGIC (4B)   | Label_Len (1 Byte)|  Label ID (N Bytes) | Nonce (12 Byte)| Ciphertext (VarLen)| Auth Tag (16B) |
|    "GDE1"     |        0x10       | "gde_febb82b998..." |  Random Bytes  |   Encrypted Data   |  Poly1305 MAC  |
+---------------+-------------------+---------------------+----------------+--------------------+----------------+
```

---

## Troubleshooting

- **Error: token revoked/expired:** Run the authentication flow again:

  ```bash
  npx -y @piotr-agier/google-drive-mcp auth
  ```

  If your OAuth consent screen is still in **Testing** status, refresh tokens expire every 7 days. Switch the publishing status to **In production** in the GCP Console to enable persistent auto-refreshing tokens.
- **`OAuth credentials not found`:** The `gcp-oauth.keys.json` file is missing from expected paths. Check [step 5](#5-save-mcp-credentials).
- **Error `redirect_uri_mismatch`:** This occurs when you select *Web application* instead of *Desktop app* in Google Cloud Console. Create a new OAuth Client ID with type **Desktop app**, download the JSON, and replace `gcp-oauth.keys.json`.
- **Port Conflict (`EADDRINUSE`):** By default, the auth server uses ports 3000–3004. If that port is already in use by another local server, change the starting port:
  ```bash
  export GOOGLE_DRIVE_MCP_AUTH_PORT=3100
  npx -y @piotr-agier/google-drive-mcp auth
  ```
- **Command `gde` not found:** Add local bin to your shell configuration:

  ```bash
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
  ```
- **Module `cryptography` missing:** Install the module via pip:

  ```bash
  pip3 install --user cryptography
  ```

---

## License

[MIT License](LICENSE) © 2026 ZanderoDev
