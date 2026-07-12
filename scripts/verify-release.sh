#!/bin/sh

set -eu

KANAE_VERSION=${KANAE_VERSION:-0.1.0}
KANAE_DIST_DIR=${KANAE_DIST_DIR:-dist}
KANAE_VERIFY_INSTALL_ROOT=${KANAE_VERIFY_INSTALL_ROOT:-/private/tmp/kanae-verify-install}

OS=$(uname -s)
if [ "$OS" != "Darwin" ]; then
  echo "error: release verification is supported on macOS only" >&2
  exit 1
fi

ARCH=$(uname -m)
case "$ARCH" in
  arm64)
    KANAE_PLATFORM="macos-arm64"
    ;;
  x86_64)
    KANAE_PLATFORM="macos-x86_64"
    ;;
  *)
    echo "error: unsupported architecture: $ARCH" >&2
    exit 1
    ;;
esac

if [ ! -d "$KANAE_DIST_DIR" ]; then
  echo "error: missing dist directory: $KANAE_DIST_DIR" >&2
  exit 1
fi

ABS_DIST_DIR=$(cd "$KANAE_DIST_DIR" && pwd)

ARCHIVE_PATH="$ABS_DIST_DIR/kanae-v${KANAE_VERSION}-${KANAE_PLATFORM}.tar.gz"
CHECKSUM_PATH="${ARCHIVE_PATH}.sha256"

if [ ! -f "$ARCHIVE_PATH" ] || [ ! -f "$CHECKSUM_PATH" ]; then
  echo "error: required release artifacts not found. Run scripts/package-release.sh first." >&2
  exit 1
fi

echo "verify: checksum"
(cd "$ABS_DIST_DIR" && shasum -a 256 -c "$(basename "$CHECKSUM_PATH")")

echo "verify: archive members"
VERIFY_TMP_DIR=$(mktemp -d)
trap 'rm -rf "$VERIFY_TMP_DIR"' EXIT
ARCHIVE_APP_EXEC="Kanae.app/Contents/MacOS/Kanae"
if tar -tzf "$ARCHIVE_PATH" | awk '$1=="Kanae.app/Contents/MacOS/Kanae" || $1=="./Kanae.app/Contents/MacOS/Kanae" { found=1; exit } END { exit !found }'; then
  ARCHIVE_APP_EXEC="$(tar -tzf "$ARCHIVE_PATH" | awk '$1=="Kanae.app/Contents/MacOS/Kanae" || $1=="./Kanae.app/Contents/MacOS/Kanae" { print $1; exit }')"
fi

if ! tar -tzf "$ARCHIVE_PATH" | grep -Eq '^(\./)?bin/kanae$'; then
  echo "error: archive missing expected binary: bin/kanae" >&2
  exit 1
fi
if ! tar -tzf "$ARCHIVE_PATH" | grep -Eq '^(\./)?Kanae\.app/$'; then
  echo "error: archive missing expected app bundle: Kanae.app/" >&2
  exit 1
fi
if ! tar -tzf "$ARCHIVE_PATH" | grep -Eq '^(\./)?Kanae\.app/Contents/Info\.plist$'; then
  echo "error: archive missing expected file: Kanae.app/Contents/Info.plist" >&2
  exit 1
fi
if ! tar -tzf "$ARCHIVE_PATH" | grep -Eq '^(\./)?Kanae\.app/Contents/MacOS/Kanae$'; then
  echo "error: archive missing expected file: Kanae.app/Contents/MacOS/Kanae" >&2
  exit 1
fi
if [ -z "${ARCHIVE_APP_EXEC:-}" ]; then
  echo "error: could not locate app executable in archive: Kanae.app/Contents/MacOS/Kanae" >&2
  exit 1
fi
ARCHIVE_TMP_EXEC="$VERIFY_TMP_DIR/$(printf '%s' "$ARCHIVE_APP_EXEC" | tr '/' '_')"
if ! tar -xOf "$ARCHIVE_PATH" "$ARCHIVE_APP_EXEC" > "$ARCHIVE_TMP_EXEC"; then
  echo "error: failed to extract app executable from archive: $ARCHIVE_APP_EXEC" >&2
  exit 1
fi
if LC_ALL=C head -c 2 "$ARCHIVE_TMP_EXEC" | grep -q "^#!"; then
  echo "error: archive app executable appears to be a shell script, expected binary executable" >&2
  exit 1
else
  echo "verify: archive app executable is binary-style (no #! script header)"
fi
if ! tar -tvf "$ARCHIVE_PATH" | awk '
{
  mode = $1
  file = $NF
  sub(/^\.\/?/, "", file)
  if (file == "Kanae.app/Contents/MacOS/Kanae" && mode ~ /^-..x/ ) {
    found_executable = 1
  }
}
END {
  exit (!found_executable)
}' >/dev/null; then
  echo "error: archived app executable is not marked executable: Kanae.app/Contents/MacOS/Kanae" >&2
  exit 1
fi
if ! tar -tzf "$ARCHIVE_PATH" | grep -Eq '^(\./)?README.md$'; then
  echo "error: archive missing expected file: README.md" >&2
  exit 1
fi

if [ -z "$KANAE_VERIFY_INSTALL_ROOT" ] || [ "$KANAE_VERIFY_INSTALL_ROOT" = "/" ] || [ "$KANAE_VERIFY_INSTALL_ROOT" = "/private" ] || [ "$KANAE_VERIFY_INSTALL_ROOT" = "/private/tmp" ] || [ "$KANAE_VERIFY_INSTALL_ROOT" = "$HOME" ]; then
  echo "error: refusing to remove unsafe install root: ${KANAE_VERIFY_INSTALL_ROOT:-<empty>}" >&2
  exit 1
fi

echo "verify: preparing install root"
rm -rf "$KANAE_VERIFY_INSTALL_ROOT"

echo "verify: running hosted installer"
(
  KANAE_BASE_URL="file://$ABS_DIST_DIR"
  KANAE_VERSION="$KANAE_VERSION"
  KANAE_INSTALL_ROOT="$KANAE_VERIFY_INSTALL_ROOT"
  KANAE_SKIP_SETUP=1
  export KANAE_BASE_URL KANAE_VERSION KANAE_INSTALL_ROOT KANAE_SKIP_SETUP
  sh docs/install
)

if [ ! -x "$KANAE_VERIFY_INSTALL_ROOT/bin/kanae" ]; then
  echo "error: installed kanae is missing or not executable" >&2
  exit 1
fi
if [ ! -x "$KANAE_VERIFY_INSTALL_ROOT/Kanae.app/Contents/MacOS/Kanae" ]; then
  echo "error: installed app executable is missing or not executable" >&2
  exit 1
fi
if head -c 2 "$KANAE_VERIFY_INSTALL_ROOT/Kanae.app/Contents/MacOS/Kanae" | LC_ALL=C grep -q "^#!"; then
  echo "error: installed app executable appears to be a shell script, expected binary executable" >&2
  exit 1
fi
if [ ! -f "$KANAE_VERIFY_INSTALL_ROOT/Kanae.app/Contents/Info.plist" ]; then
  echo "error: installed app Info.plist is missing" >&2
  exit 1
fi
if [ "$(plutil -extract CFBundleIdentifier raw "$KANAE_VERIFY_INSTALL_ROOT/Kanae.app/Contents/Info.plist")" != "dev.ultrahope.kanae" ]; then
  echo "error: installed app has an unexpected bundle identifier" >&2
  exit 1
fi
if [ "$(plutil -extract CFBundleExecutable raw "$KANAE_VERIFY_INSTALL_ROOT/Kanae.app/Contents/Info.plist")" != "Kanae" ]; then
  echo "error: installed app has an unexpected executable name" >&2
  exit 1
fi

echo "verify: isolated setup"
VERIFY_SETUP_LOG="$VERIFY_TMP_DIR/verify-setup.log"
if ! (
  KANAE_INSTALL_ROOT="$KANAE_VERIFY_INSTALL_ROOT" \
  KANAE_LAUNCH_AGENT_DIR="$KANAE_VERIFY_INSTALL_ROOT/.verify-agents" \
  KANAE_STATE_DIR="$KANAE_VERIFY_INSTALL_ROOT/.verify-state" \
  KANAE_CONFIG_DIR="$KANAE_VERIFY_INSTALL_ROOT/.verify-config" \
  "$KANAE_VERIFY_INSTALL_ROOT/bin/kanae" install --no-open --no-start --wait-accessibility 0
) >"$VERIFY_SETUP_LOG" 2>&1; then
  cat "$VERIFY_SETUP_LOG"
  echo "error: isolated setup command failed" >&2
  exit 1
fi

if [ ! -f "$KANAE_VERIFY_INSTALL_ROOT/.verify-agents/dev.ultrahope.kanae.plist" ]; then
  cat "$VERIFY_SETUP_LOG"
  echo "error: isolated setup did not write LaunchAgent plist" >&2
  exit 1
fi
if [ ! -f "$KANAE_VERIFY_INSTALL_ROOT/.verify-state/setup.log" ]; then
  cat "$VERIFY_SETUP_LOG"
  echo "error: isolated setup did not write setup log" >&2
  exit 1
fi
if [ ! -f "$KANAE_VERIFY_INSTALL_ROOT/.verify-config/config.json" ]; then
  cat "$VERIFY_SETUP_LOG"
  echo "error: isolated setup did not write default config" >&2
  exit 1
fi
if grep -Fq "Registering LaunchAgent" "$VERIFY_SETUP_LOG"; then
  cat "$VERIFY_SETUP_LOG"
  echo "error: isolated setup attempted to register LaunchAgent" >&2
  exit 1
fi
rm -f "$VERIFY_SETUP_LOG"

KANAE_INSTALL_ROOT="$KANAE_VERIFY_INSTALL_ROOT" \
KANAE_LAUNCH_AGENT_DIR="$KANAE_VERIFY_INSTALL_ROOT/.verify-agents" \
KANAE_STATE_DIR="$KANAE_VERIFY_INSTALL_ROOT/.verify-state" \
KANAE_CONFIG_DIR="$KANAE_VERIFY_INSTALL_ROOT/.verify-config" \
"$KANAE_VERIFY_INSTALL_ROOT/bin/kanae" status >/dev/null

cat <<EOF
verification passed:
- release artifacts: checksum + archive members
- hosted installer path: docs/install
- installed binary: $KANAE_VERIFY_INSTALL_ROOT/bin/kanae
- installed app: $KANAE_VERIFY_INSTALL_ROOT/Kanae.app
- app identity: dev.ultrahope.kanae / Kanae
- isolated setup: install --no-open --no-start --wait-accessibility 0
- default bindings config: $KANAE_VERIFY_INSTALL_ROOT/.verify-config/config.json
- CLI status check: kanae status
EOF
