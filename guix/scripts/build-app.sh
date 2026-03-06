#!/usr/bin/env bash
# Build the cs_monero example Flutter app inside a Guix shell.
# Requires monero_c libs to already be built (run build-monero-c.sh first).
#
# Usage:
#   guix/scripts/build-app.sh              # latest local Guix
#   guix/scripts/build-app.sh --pinned     # fully reproducible
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SDK_DIR="$PROJECT_ROOT/.flutter-sdk/flutter"

if [ ! -d "$SDK_DIR" ]; then
    echo "Flutter SDK not found. Run 'make -C guix setup' first."
    exit 1
fi

GUIX_CMD=(guix)
if [ "${1:-}" = "--pinned" ]; then
    GUIX_CMD=(guix time-machine -C "$PROJECT_ROOT/guix/channels.scm" --)
fi

echo "Building cs_monero example app in Guix shell..."

export CS_MONERO_PROJECT_ROOT="$PROJECT_ROOT"
export CS_MONERO_SDK_DIR="$SDK_DIR"

"${GUIX_CMD[@]}" shell \
    -m "$PROJECT_ROOT/guix/linux.scm" \
    --preserve='^CS_MONERO_' \
    -- bash -c '
set -euo pipefail
export PATH="$CS_MONERO_SDK_DIR/bin:$PATH"
export FLUTTER_ROOT="$CS_MONERO_SDK_DIR"
export CC=clang
export CXX=clang++

# Ensure SSL certs are visible to pub/curl inside Guix shell.
if [ -n "${SSL_CERT_DIR:-}" ]; then
    export CURL_CA_BUNDLE="$SSL_CERT_DIR/ca-certificates.crt"
    export GIT_SSL_CAINFO="$CURL_CA_BUNDLE"
fi

cd "$CS_MONERO_PROJECT_ROOT"

echo "--- melos bootstrap ---"
dart pub global activate melos
export PATH="$HOME/.pub-cache/bin:$PATH"
melos bootstrap

echo "--- flutter build linux (example_app) ---"
cd example_app
flutter pub get
flutter build linux --release

echo ""
echo "Build complete. Output at:"
find build/linux -path "*/release/bundle" -type d -exec ls -la {} + 2>/dev/null
'
