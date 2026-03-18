#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_DIR="${HOME}/.local/bin"
CSHIP_CONFIG="${HOME}/.config/cship.toml"
SETTINGS="${HOME}/.claude/settings.json"

# ── 1. OS / Arch Detection ───────────────────────────────────────────────────
OS=$(uname -s)
ARCH=$(uname -m)

case "$OS" in
  Darwin)
    case "$ARCH" in
      arm64)  TARGET="aarch64-apple-darwin" ;;
      x86_64) TARGET="x86_64-apple-darwin" ;;
      *)      echo "ERROR: Unsupported macOS arch: $ARCH" >&2; exit 1 ;;
    esac
    ;;
  Linux)
    case "$ARCH" in
      x86_64)  TARGET="x86_64-unknown-linux-musl" ;;
      aarch64) TARGET="aarch64-unknown-linux-musl" ;;
      *)       echo "ERROR: Unsupported Linux arch: $ARCH" >&2; exit 1 ;;
    esac
    ;;
  *)
    echo "ERROR: Unsupported OS: $OS" >&2; exit 1 ;;
esac

echo "cship: detected $OS/$ARCH → target: $TARGET"

# ── 2. Download Binary ───────────────────────────────────────────────────────
BINARY_URL="https://github.com/stephenleo/cship/releases/latest/download/cship-${TARGET}"
mkdir -p "$INSTALL_DIR"
echo "cship: downloading from $BINARY_URL ..."
curl -fsSL "$BINARY_URL" -o "${INSTALL_DIR}/cship"
chmod +x "${INSTALL_DIR}/cship"

if [ ! -s "${INSTALL_DIR}/cship" ]; then
  echo "ERROR: downloaded binary is empty — check network or release URL" >&2
  rm -f "${INSTALL_DIR}/cship"
  exit 1
fi
echo "cship: installed to ${INSTALL_DIR}/cship"

# ── 3. Symlink cship.toml (Starship-aware) ───────────────────────────────────
mkdir -p "$(dirname "$CSHIP_CONFIG")"

if command -v starship >/dev/null 2>&1; then
  echo "cship: starship found — using starship config variant"
  SOURCE_CONFIG="${REPO_DIR}/configs/cship-starship.toml"
else
  echo "cship: starship not found — using basic config variant"
  echo "cship: install starship (https://starship.rs) and re-run to enable full prompt"
  SOURCE_CONFIG="${REPO_DIR}/configs/cship.toml"
fi

ln -sf "$SOURCE_CONFIG" "$CSHIP_CONFIG"
echo "cship: symlinked $CSHIP_CONFIG -> $SOURCE_CONFIG"

# ── 4. Wire statusLine in settings.json ───────────────────────────────────────
if ! command -v python3 >/dev/null 2>&1; then
  echo "WARNING: python3 not found — skipping settings.json update"
  echo "  Add manually: \"statusLine\": {\"type\": \"command\", \"command\": \"cship\"}"
  exit 0
fi

if [ -f "$SETTINGS" ]; then
  python3 - "$SETTINGS" <<'PYEOF'
import json, sys
path = sys.argv[1]
try:
    with open(path) as f:
        d = json.load(f)
except (json.JSONDecodeError, ValueError) as e:
    print(f"WARNING: {path} contains invalid JSON: {e}")
    sys.exit(1)
d["statusLine"] = {"type": "command", "command": "cship"}
with open(path, "w") as f:
    json.dump(d, f, indent=2)
    f.write("\n")
print(f"cship: updated statusLine in {path}")
PYEOF
else
  echo "cship: settings.json not found at $SETTINGS — skipping"
fi

echo ""
echo "cship: installation complete!"
