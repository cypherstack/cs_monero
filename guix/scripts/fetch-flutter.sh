#!/usr/bin/env bash
# Download and verify a pinned Flutter SDK.
# The SDK is stored in .flutter-sdk/ (git-ignored).
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$PROJECT_ROOT/guix/flutter_version.env"

SDK_DIR="$PROJECT_ROOT/.flutter-sdk"

# Detect host architecture.
case "$(uname -m)" in
    x86_64|amd64)  ARCH="" ;;
    aarch64|arm64) ARCH="_arm64" ;;
    *) echo "Unsupported architecture: $(uname -m)"; exit 1 ;;
esac

ARCHIVE="flutter_linux${ARCH}_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.tar.xz"
URL="https://storage.googleapis.com/flutter_infra_release/releases/${FLUTTER_CHANNEL}/linux/$ARCHIVE"

if [ -d "$SDK_DIR/flutter" ] && "$SDK_DIR/flutter/bin/flutter" --version 2>/dev/null | grep -q "$FLUTTER_VERSION"; then
    echo "Flutter $FLUTTER_VERSION already present in $SDK_DIR"
    exit 0
fi

echo "Downloading Flutter $FLUTTER_VERSION ($FLUTTER_CHANNEL) for $(uname -m)..."
mkdir -p "$SDK_DIR"
cd "$SDK_DIR"

curl -LO "$URL"

# Select the correct hash for this architecture.
HASH=""
if [ -n "$ARCH" ] && [ -n "${FLUTTER_SHA256_ARM64:-}" ]; then
    HASH="$FLUTTER_SHA256_ARM64"
elif [ -z "$ARCH" ] && [ -n "${FLUTTER_SHA256_X64:-}" ]; then
    HASH="$FLUTTER_SHA256_X64"
fi

if [ -n "$HASH" ]; then
    echo "Verifying checksum..."
    echo "$HASH  $ARCHIVE" | sha256sum -c -
else
    echo "WARNING: No SHA-256 hash set for $(uname -m) in flutter_version.env."
    COMPUTED="$(sha256sum "$ARCHIVE" | cut -d' ' -f1)"
    echo "Computed hash: $COMPUTED"
    if [ -z "$ARCH" ]; then
        echo "Add to guix/flutter_version.env:  FLUTTER_SHA256_X64=\"$COMPUTED\""
    else
        echo "Add to guix/flutter_version.env:  FLUTTER_SHA256_ARM64=\"$COMPUTED\""
    fi
fi

echo "Extracting..."
tar xf "$ARCHIVE"
rm "$ARCHIVE"

echo "Flutter SDK ready at $SDK_DIR/flutter"
echo "Version:"
"$SDK_DIR/flutter/bin/flutter" --version
