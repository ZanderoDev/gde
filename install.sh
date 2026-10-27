#!/usr/bin/env bash
set -e

# ANSI Colors
BOLD="\033[1m"
GREEN="\033[92m"
CYAN="\033[96m"
YELLOW="\033[93m"
RED="\033[91m"
RESET="\033[0m"

CONFIG_DIR="$HOME/.config/gde"
CONFIG_FILE="$CONFIG_DIR/config.json"
mkdir -p "$CONFIG_DIR"

SELECTED_LANG=""
# Check command line flags for language preference
for arg in "$@"; do
    case "$arg" in
        --lang=en|-en|en)
            SELECTED_LANG="en"
            ;;
        --lang=id|-id|id)
            SELECTED_LANG="id"
            ;;
    esac
done

# If not specified via flag, check existing config or prompt on first install
if [ -z "$SELECTED_LANG" ]; then
    if [ -f "$CONFIG_FILE" ]; then
        SAVED_LANG=$(grep -o '"lang": *"[^"]*"' "$CONFIG_FILE" 2>/dev/null | cut -d'"' -f4)
        if [ "$SAVED_LANG" = "en" ]; then
            SELECTED_LANG="en"
        else
            SELECTED_LANG="id"
        fi
    else
        echo -e "\n${BOLD}${CYAN}╔═════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${BOLD}${CYAN}║             GDE (Google Drive Encryption) Installer         ║${RESET}"
        echo -e "${BOLD}${CYAN}╚═════════════════════════════════════════════════════════════╝${RESET}\n"
        echo -e "${BOLD}Pilih bahasa instalasi / Select installation language:${RESET}"
        echo -e "  ${BOLD}[1]${RESET} Bahasa Indonesia (default)"
        echo -e "  ${BOLD}[2]${RESET} English"
        
        if [ -t 0 ]; then
            read -r -p "Pilihan / Selection [1/2]: " USER_CHOICE
            if [[ "$USER_CHOICE" == "2" || "$USER_CHOICE" == "en" || "$USER_CHOICE" == "EN" ]]; then
                SELECTED_LANG="en"
            else
                SELECTED_LANG="id"
            fi
        else
            SELECTED_LANG="id"
        fi
    fi
fi

# Save selected language preference
echo "{\"lang\": \"$SELECTED_LANG\"}" > "$CONFIG_FILE"
chmod 600 "$CONFIG_FILE"

# Define bilingual messages
if [ "$SELECTED_LANG" = "en" ]; then
    MSG_HEADER="GDE (Google Drive Encryption) Installer"
    MSG_CHECK_PY="Checking Python 3..."
    MSG_NO_PY="Python 3 not found! Please install Python 3 first."
    MSG_PY_DETECTED="Python %s detected."
    MSG_CHECK_NODE="Checking Node.js & npx..."
    MSG_NO_NPX="'npx' not found! GDE needs npx for Google Drive MCP connection."
    MSG_INSTALL_NODE="Install Node.js from https://nodejs.org or via package manager."
    MSG_OFFLINE_NOTE="Note: Offline mode (gde --local) still works without npx."
    MSG_NPX_DETECTED="npx v%s detected."
    MSG_CHECK_CRYPTO="Checking 'cryptography' library..."
    MSG_INSTALL_CRYPTO="Installing 'cryptography' module..."
    MSG_CRYPTO_READY="'cryptography' library is ready."
    MSG_INSTALLING_BIN="Installing binary to %s/gde..."
    MSG_NO_SCRIPT="Source file 'gde' not found at %s!"
    MSG_PATH_WARN="%s is not in your \$PATH yet."
    MSG_PATH_HINT="Add the following line to ~/.bashrc or ~/.zshrc:"
    MSG_RUN_TEST="Running GDE self-test..."
    MSG_CHECK_MCP="Checking Google Drive MCP configuration..."
    MSG_GCP_FOUND="Google Cloud OAuth credentials found."
    MSG_TOKEN_FOUND="Google Drive authorization token found."
    MSG_TOKEN_MISSING="Token not active yet. Run authorization with:"
    MSG_NO_GCP="No Google Drive MCP credentials found yet."
    MSG_GCP_HINT="Follow the GCP setup guide in README.md to enable GDrive sync."
    MSG_DONE="Done! 'gde' command is ready to use."
else
    # Bahasa Indonesia (humanizer-id dev/casual style)
    MSG_HEADER="Installer GDE (Google Drive Encryption)"
    MSG_CHECK_PY="Cek Python 3..."
    MSG_NO_PY="Python 3 nggak ketemu! Install Python 3 dulu ya."
    MSG_PY_DETECTED="Python %s udah terpasang."
    MSG_CHECK_NODE="Cek Node.js & npx..."
    MSG_NO_NPX="'npx' nggak ketemu! GDE butuh npx buat koneksi ke Google Drive MCP."
    MSG_INSTALL_NODE="Install Node.js dari https://nodejs.org atau lewat package manager."
    MSG_OFFLINE_NOTE="Catatan: Mode offline (gde --local) tetap bisa jalan tanpa npx."
    MSG_NPX_DETECTED="npx v%s siap dipakai."
    MSG_CHECK_CRYPTO="Cek library 'cryptography'..."
    MSG_INSTALL_CRYPTO="Pasang modul 'cryptography'..."
    MSG_CRYPTO_READY="Library cryptography udah siap."
    MSG_INSTALLING_BIN="Pasang binary ke %s/gde..."
    MSG_NO_SCRIPT="File sumber 'gde' nggak ketemu di %s!"
    MSG_PATH_WARN="%s belum ada di \$PATH kamu."
    MSG_PATH_HINT="Tambahkan baris ini ke ~/.bashrc atau ~/.zshrc:"
    MSG_RUN_TEST="Jalankan self-test GDE..."
    MSG_CHECK_MCP="Cek konfigurasi Google Drive MCP..."
    MSG_GCP_FOUND="Kredensial Google Cloud OAuth udah ada."
    MSG_TOKEN_FOUND="Token akses Google Drive udah aktif."
    MSG_TOKEN_MISSING="Token belum aktif. Jalankan login/otorisasi:"
    MSG_NO_GCP="Belum ada kredensial Google Drive MCP."
    MSG_GCP_HINT="Ikuti panduan setup GCP di README.md buat aktifin upload ke GDrive."
    MSG_DONE="Beres! Perintah 'gde' udah siap dipakai."
fi

echo -e "\n${BOLD}${CYAN}╔═════════════════════════════════════════════════════════════╗${RESET}"
printf "${BOLD}${CYAN}║ %-59s ║${RESET}\n" "$MSG_HEADER"
echo -e "${BOLD}${CYAN}╚═════════════════════════════════════════════════════════════╝${RESET}\n"

# 1. Check Python 3
echo -e "${CYAN}[*] $MSG_CHECK_PY${RESET}"
if ! command -v python3 &>/dev/null; then
    echo -e "${RED}[-] $MSG_NO_PY${RESET}"
    exit 1
fi
PY_VER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
printf "${GREEN}[+] $MSG_PY_DETECTED${RESET}\n" "$PY_VER"

# 2. Check Node.js and npx
echo -e "${CYAN}[*] $MSG_CHECK_NODE${RESET}"
if ! command -v npx &>/dev/null; then
    echo -e "${YELLOW}[!] $MSG_NO_NPX${RESET}"
    echo -e "${YELLOW}[!] $MSG_INSTALL_NODE${RESET}"
    echo -e "${YELLOW}[!] $MSG_OFFLINE_NOTE${RESET}"
else
    NPX_VER=$(npx -v)
    printf "${GREEN}[+] $MSG_NPX_DETECTED${RESET}\n" "$NPX_VER"
fi

# 3. Check / Install Python Cryptography
echo -e "${CYAN}[*] $MSG_CHECK_CRYPTO${RESET}"
if ! python3 -c "from cryptography.hazmat.primitives.ciphers.aead import ChaCha20Poly1305" &>/dev/null; then
    echo -e "${YELLOW}[*] $MSG_INSTALL_CRYPTO${RESET}"
    pip3 install --user cryptography || pip install --user cryptography || pip3 install cryptography --break-system-packages
fi
echo -e "${GREEN}[+] $MSG_CRYPTO_READY${RESET}"

# 4. Install gde binary
INSTALL_DIR="$HOME/.local/bin"
mkdir -p "$INSTALL_DIR"

SCRIPT_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/gde"
if [ ! -f "$SCRIPT_SRC" ]; then
    printf "${RED}[-] $MSG_NO_SCRIPT${RESET}\n" "$SCRIPT_SRC"
    exit 1
fi

printf "${CYAN}[*] $MSG_INSTALLING_BIN${RESET}\n" "$INSTALL_DIR"
cp "$SCRIPT_SRC" "$INSTALL_DIR/gde"
chmod +x "$INSTALL_DIR/gde"
ln -sf "$INSTALL_DIR/gde" "$INSTALL_DIR/egd"

# 5. Check PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    printf "${YELLOW}[!] $MSG_PATH_WARN${RESET}\n" "$INSTALL_DIR"
    echo -e "${YELLOW}    $MSG_PATH_HINT${RESET}"
    echo -e "    ${BOLD}export PATH=\"\$HOME/.local/bin:\$PATH\"${RESET}"
fi

# 6. Run Self Test
echo -e "${CYAN}[*] $MSG_RUN_TEST${RESET}"
"$INSTALL_DIR/gde" test

# 7. Check GDrive MCP config
MCP_CONFIG_DIR="$HOME/.config/google-drive-mcp"
echo -e "\n${CYAN}[*] $MSG_CHECK_MCP${RESET}"
if [ -f "$MCP_CONFIG_DIR/gcp-oauth.keys.json" ]; then
    echo -e "${GREEN}[+] $MSG_GCP_FOUND${RESET}"
    if [ -f "$MCP_CONFIG_DIR/tokens.json" ]; then
        echo -e "${GREEN}[+] $MSG_TOKEN_FOUND${RESET}"
    else
        echo -e "${YELLOW}[!] $MSG_TOKEN_MISSING${RESET}"
        echo -e "    ${BOLD}npx -y @piotr-agier/google-drive-mcp${RESET}"
    fi
else
    echo -e "${YELLOW}[!] $MSG_NO_GCP${RESET}"
    echo -e "${YELLOW}    $MSG_GCP_HINT${RESET}"
fi

echo -e "\n${BOLD}${GREEN}[✓] $MSG_DONE${RESET}\n"
