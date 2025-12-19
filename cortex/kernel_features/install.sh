#!/usr/bin/env bash
set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
NC="\033[0m"

# Cortex Linux installer (Debian / Ubuntu)
# Usage: curl -fsSL https://cortexlinux.com/install.sh | bash

error() {
  echo -e "${RED}ERROR: $*${NC}" >&2
  exit 1
}

echo "🧠 Cortex Linux Installer"

# Detect OS (Debian / Ubuntu only)
if [[ -r /etc/os-release ]]; then
  source /etc/os-release
  OS_ID=$(printf '%s' "${ID:-}" | tr '[:upper:]' '[:lower:]')
  OS_LIKE=$(printf '%s' "${ID_LIKE:-}" | tr '[:upper:]' '[:lower:]')
else
  error "Cannot detect OS"
fi

if [[ "$OS_ID" != "ubuntu" && "$OS_ID" != "debian" && ! "$OS_LIKE" =~ debian ]]; then
  error "Unsupported OS: $OS_ID"
fi

# Check Python 3.10+
command -v python3 >/dev/null 2>&1 || \
  error "python3 not found. Install Python 3.10+"

read -r PY_MAJOR PY_MINOR <<< "$(python3 - <<EOF
import sys
print(sys.version_info.major, sys.version_info.minor)
EOF
)"

if [[ "$PY_MAJOR" -lt 3 || ( "$PY_MAJOR" -eq 3 && "$PY_MINOR" -lt 10 ) ]]; then
  error "Python 3.10+ required"
fi

echo "Detected: ${PRETTY_NAME%% LTS}, Python ${PY_MAJOR}.${PY_MINOR}"
echo "Installing to ~/.cortex..."

# Create / validate virtual environment
CORTEX_HOME="$HOME/.cortex"
VENV_PATH="$CORTEX_HOME/venv"
mkdir -p "$CORTEX_HOME"

if [[ ! -d "$VENV_PATH" || ! -f "$VENV_PATH/bin/activate" ]]; then
  rm -rf "$VENV_PATH"
  python3 -m venv "$VENV_PATH"
fi

# Install Cortex using venv pip (no PATH masking)
"$VENV_PATH/bin/pip" install --upgrade pip

CORTEX_PKG_SPEC="${CORTEX_PKG_SPEC:-cortex-linux==0.1.0}"
CORTEX_PIP_HASH_FILE="${CORTEX_PIP_HASH_FILE:-}"

if [[ -n "$CORTEX_PIP_HASH_FILE" ]]; then
  PIP_INSTALL_CMD=("$VENV_PATH/bin/pip" install --require-hashes -r "$CORTEX_PIP_HASH_FILE")
else
  PIP_INSTALL_CMD=("$VENV_PATH/bin/pip" install "$CORTEX_PKG_SPEC")
fi

if ! "${PIP_INSTALL_CMD[@]}"; then
  command -v git >/dev/null 2>&1 || error "git not available for fallback install"
  CORTEX_REPO_URL="${CORTEX_REPO_URL:-https://github.com/cortexlinux/cortex.git}"
  CORTEX_REPO_BRANCH="${CORTEX_REPO_BRANCH:-main}"
  TMP_DIR=$(mktemp -d)
  git clone --depth 1 --single-branch --branch "$CORTEX_REPO_BRANCH" "$CORTEX_REPO_URL" "$TMP_DIR" || \
    error "git clone failed from $CORTEX_REPO_URL (branch: $CORTEX_REPO_BRANCH)"
  "$VENV_PATH/bin/pip" install "$TMP_DIR"
  rm -rf "$TMP_DIR"
fi

# Ensure cortex binary exists
if [[ ! -x "$VENV_PATH/bin/cortex" ]]; then
  error "cortex binary not found after installation"
fi

# Expose cortex CLI
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
ln -sf "$VENV_PATH/bin/cortex" "$BIN_DIR/cortex" || \
  error "Failed to create cortex symlink at '$BIN_DIR/cortex'."

# Persist PATH update
for rc in "$HOME/.profile" "$HOME/.bashrc" "$HOME/.bash_profile"; do
  [[ -f "$rc" ]] || continue
  grep -q 'PATH.*\.local/bin' "$rc" && continue
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
done

# Store API key if present (preserve existing env)
ENV_FILE="$CORTEX_HOME/.env"
if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
  touch "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  grep -v '^ANTHROPIC_API_KEY=' "$ENV_FILE" > "${ENV_FILE}.tmp" || true
  mv "${ENV_FILE}.tmp" "$ENV_FILE"
  echo "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY" >> "$ENV_FILE"
fi

# Verify installation
CORTEX_CMD="$BIN_DIR/cortex"
[[ -x "$CORTEX_CMD" ]] || CORTEX_CMD="$VENV_PATH/bin/cortex"

"$CORTEX_CMD" --help >/dev/null 2>&1 || \
  error "cortex installed but failed to run"

echo "✅ Installed! Run: cortex --help to get started."
