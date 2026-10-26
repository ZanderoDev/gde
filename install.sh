#!/usr/bin/env bash
set -e

# ANSI Colors
BOLD="\033[1m"
GREEN="\033[92m"
CYAN="\033[96m"
YELLOW="\033[93m"
RED="\033[91m"
RESET="\033[0m"

echo -e "\n${BOLD}${CYAN}╔═════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${CYAN}║             GDE (Google Drive Encryption) Installer         ║${RESET}"
echo -e "${BOLD}${CYAN}╚═════════════════════════════════════════════════════════════╝${RESET}\n"

# 1. Check Python 3
echo -e "${CYAN}[*] Memeriksa Python 3...${RESET}"
if ! command -v python3 &>/dev/null; then
    echo -e "${RED}[-] Python 3 tidak ditemukan! Silakan install Python 3 terlebih dahulu.${RESET}"
    exit 1
fi
PY_VER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
echo -e "${GREEN}[+] Python $PY_VER terdeteksi.${RESET}"

# 2. Check Node.js and npx
echo -e "${CYAN}[*] Memeriksa Node.js & npx...${RESET}"
if ! command -v npx &>/dev/null; then
    echo -e "${YELLOW}[!] 'npx' tidak ditemukan! GDE butuh npx untuk koneksi Google Drive MCP.${RESET}"
    echo -e "${YELLOW}[!] Install Node.js dari https://nodejs.org atau via package manager.${RESET}"
    echo -e "${YELLOW}[!] Catatan: Mode offline (gde --local) tetap bisa berjalan tanpa npx.${RESET}"
else
    NPX_VER=$(npx -v)
    echo -e "${GREEN}[+] npx v$NPX_VER terdeteksi.${RESET}"
fi

# 3. Check / Install Python Cryptography
echo -e "${CYAN}[*] Memeriksa library 'cryptography'...${RESET}"
if ! python3 -c "from cryptography.hazmat.primitives.ciphers.aead import ChaCha20Poly1305" &>/dev/null; then
    echo -e "${YELLOW}[*] Menginstall modul 'cryptography'...${RESET}"
    pip3 install --user cryptography || pip install --user cryptography || pip3 install cryptography --break-system-packages
fi
echo -e "${GREEN}[+] Library cryptography siap.${RESET}"

# 4. Install gde binary
INSTALL_DIR="$HOME/.local/bin"
mkdir -p "$INSTALL_DIR"

SCRIPT_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/gde"
if [ ! -f "$SCRIPT_SRC" ]; then
    echo -e "${RED}[-] File sumber 'gde' tidak ditemukan di $SCRIPT_SRC!${RESET}"
    exit 1
fi

echo -e "${CYAN}[*] Memasang binary ke $INSTALL_DIR/gde...${RESET}"
cp "$SCRIPT_SRC" "$INSTALL_DIR/gde"
chmod +x "$INSTALL_DIR/gde"
ln -sf "$INSTALL_DIR/gde" "$INSTALL_DIR/egd"

# 5. Check PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo -e "${YELLOW}[!] $INSTALL_DIR belum ada di \$PATH Anda.${RESET}"
    echo -e "${YELLOW}    Tambahkan baris berikut ke ~/.bashrc atau ~/.zshrc:${RESET}"
    echo -e "    ${BOLD}export PATH=\"\$HOME/.local/bin:\$PATH\"${RESET}"
fi

# 6. Run Self Test
echo -e "${CYAN}[*] Menjalankan self-test GDE...${RESET}"
"$INSTALL_DIR/gde" test

# 7. Check GDrive MCP config
MCP_CONFIG_DIR="$HOME/.config/google-drive-mcp"
echo -e "\n${CYAN}[*] Memeriksa konfigurasi Google Drive MCP...${RESET}"
if [ -f "$MCP_CONFIG_DIR/gcp-oauth.keys.json" ]; then
    echo -e "${GREEN}[+] Google Cloud OAuth credentials ditemukan.${RESET}"
    if [ -f "$MCP_CONFIG_DIR/tokens.json" ]; then
        echo -e "${GREEN}[+] Token otorisasi Google Drive ditemukan.${RESET}"
    else
        echo -e "${YELLOW}[!] Token belum aktif. Jalankan otorisasi dengan:${RESET}"
        echo -e "    ${BOLD}npx -y @piotr-agier/google-drive-mcp${RESET}"
    fi
else
    echo -e "${YELLOW}[!] Belum ada kredensial Google Drive MCP.${RESET}"
    echo -e "${YELLOW}    Silakan ikuti panduan setup GCP di README.md untuk mengaktifkan sinkronisasi GDrive.${RESET}"
fi

echo -e "\n${BOLD}${GREEN}[✓] Instalasi selesai! Perintah 'gde' siap digunakan.${RESET}\n"
