#!/usr/bin/env bash
# Build monero_c native libraries inside a Guix shell.
# This is the core reproducible build step — compiles the C/C++ monero
# wallet library that cs_monero's FFI bindings depend on.
#
# Usage:
#   guix/scripts/build-monero-c.sh              # latest local Guix
#   guix/scripts/build-monero-c.sh --pinned     # fully reproducible
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SDK_DIR="$PROJECT_ROOT/.flutter-sdk/flutter"

if [ ! -d "$SDK_DIR" ]; then
    echo "Flutter SDK not found. Run 'make -C guix setup' first."
    exit 1
fi

GUIX_CMD=(guix)
if [ "${1:-}" = "--pinned" ]; then
    echo "Using pinned channels for reproducible build."
    GUIX_CMD=(guix time-machine -C "$PROJECT_ROOT/guix/channels.scm" --)
fi

echo "Building monero_c native libraries in Guix shell..."

export CS_MONERO_PROJECT_ROOT="$PROJECT_ROOT"
export CS_MONERO_SDK_DIR="$SDK_DIR"

"${GUIX_CMD[@]}" shell \
    -m "$PROJECT_ROOT/guix/linux.scm" \
    --preserve='^CS_MONERO_' \
    -- bash -c '
set -euo pipefail
export PATH="$CS_MONERO_SDK_DIR/bin:$PATH"
export FLUTTER_ROOT="$CS_MONERO_SDK_DIR"

# Ensure SSL certs are visible to curl/git inside nested build systems.
if [ -n "${SSL_CERT_DIR:-}" ]; then
    export CURL_CA_BUNDLE="$SSL_CERT_DIR/ca-certificates.crt"
    export GIT_SSL_CAINFO="$CURL_CA_BUNDLE"
fi

cd "$CS_MONERO_PROJECT_ROOT"

echo "--- melos bootstrap ---"
dart pub global activate melos
export PATH="$HOME/.pub-cache/bin:$PATH"
melos bootstrap

echo "--- melos prepareMoneroC ---"
melos run prepareMoneroC

# Patch monero_c build_single.sh for Guix compatibility.
# monero_c uses "env -i PATH=... CC=gcc CXX=g++ make" which strips the
# entire environment. Guix's toolchain relies on env vars like
# C_INCLUDE_PATH, LIBRARY_PATH, SSL_CERT_DIR, ACLOCAL_PATH, etc.
# Replace env -i with a simple CC/CXX override that preserves the env.
BSSH="$CS_MONERO_PROJECT_ROOT/build/monero_c/build_single.sh"
if [ -f "$BSSH" ] && grep -q "env -i PATH" "$BSSH"; then
    echo "Patching build_single.sh for Guix compatibility..."
    sed -i "s|env -i PATH=\"\$PATH\" CC=gcc CXX=g++|CC=gcc CXX=g++ GITIAN=1|" "$BSSH"
fi

echo "--- melos build:linux ---"
melos run build:linux

echo "--- melos copyLibs ---"
melos run copyLibs

echo ""
echo "monero_c native libraries built and copied successfully."
echo "Built outputs:"
find built_outputs/linux -type f 2>/dev/null || echo "  (check built_outputs/)"
echo ""
echo "Copied to packages:"
find cs_monero_flutter_libs_linux/linux/lib -type f 2>/dev/null || echo "  (check cs_monero_flutter_libs_linux/linux/lib/)"
'
