#!/bin/sh

set -eu

KANAE_VERSION=${KANAE_VERSION:-0.1.0}
KANAE_DIST_DIR=${KANAE_DIST_DIR:-dist}

OS=$(uname -s)
if [ "$OS" != "Darwin" ]; then
  echo "error: release packaging is supported on macOS only" >&2
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

STAGING_DIR="$KANAE_DIST_DIR/.staging/kanae-v${KANAE_VERSION}-${KANAE_PLATFORM}"
STAGING_APP_DIR="$STAGING_DIR/Kanae.app"
APP_TEMPLATE_DIR="resources/Kanae.app"
ARCHIVE_NAME="kanae-v${KANAE_VERSION}-${KANAE_PLATFORM}.tar.gz"
ARCHIVE_PATH="$KANAE_DIST_DIR/$ARCHIVE_NAME"

if [ ! -f "$APP_TEMPLATE_DIR/Contents/Info.plist" ]; then
  echo "error: missing app template Info.plist: $APP_TEMPLATE_DIR/Contents/Info.plist" >&2
  exit 1
fi

mkdir -p "$KANAE_DIST_DIR"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR/bin"
mkdir -p "$STAGING_APP_DIR"
cp -R "$APP_TEMPLATE_DIR/Contents" "$STAGING_APP_DIR/"
mkdir -p "$STAGING_APP_DIR/Contents/MacOS"

swift build -c release

cp .build/release/kanae "$STAGING_DIR/bin/kanae"
chmod +x "$STAGING_DIR/bin/kanae"
cp README.md "$STAGING_DIR/README.md"

if [ -f LICENSE ]; then
  cp LICENSE "$STAGING_DIR/LICENSE"
else
  echo "warning: LICENSE file not found, skipping archive inclusion" >&2
fi
cp .build/release/kanae "$STAGING_APP_DIR/Contents/MacOS/Kanae"
chmod +x "$STAGING_APP_DIR/Contents/MacOS/Kanae"

tar -czf "$ARCHIVE_PATH" -C "$STAGING_DIR" .
(cd "$KANAE_DIST_DIR" && shasum -a 256 "$ARCHIVE_NAME" > "$ARCHIVE_NAME.sha256")

echo "created: $ARCHIVE_PATH"
echo "checksum: ${ARCHIVE_PATH}.sha256"
