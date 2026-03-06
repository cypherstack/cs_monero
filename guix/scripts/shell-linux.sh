#!/usr/bin/env bash
# Enter a reproducible Guix development shell for cs_monero Linux development.
#
# Usage:
#   guix/scripts/shell-linux.sh              # uses latest local Guix
#   guix/scripts/shell-linux.sh --pinned     # uses pinned channels (fully reproducible)
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SDK_DIR="$PROJECT_ROOT/.flutter-sdk/flutter"

if [ ! -d "$SDK_DIR" ]; then
    echo "Flutter SDK not found. Run 'make -C guix setup' or 'guix/scripts/fetch-flutter.sh' first."
    exit 1
fi

# Build the guix shell command.
GUIX_CMD=(guix)

if [ "${1:-}" = "--pinned" ]; then
    echo "Using pinned channels from guix/channels.scm"
    GUIX_CMD=(guix time-machine -C "$PROJECT_ROOT/guix/channels.scm" --)
fi

echo "Entering Guix shell with monero_c + Flutter Linux dependencies..."
echo "Flutter SDK: $SDK_DIR"

exec "${GUIX_CMD[@]}" shell \
    -m "$PROJECT_ROOT/guix/linux.scm" \
    --preserve='^DISPLAY$' \
    --preserve='^WAYLAND_DISPLAY$' \
    --preserve='^XAUTHORITY$' \
    --preserve='^XDG_' \
    --preserve='^DBUS_' \
    -- bash --init-file <(cat <<INITEOF
export PATH="$SDK_DIR/bin:\$PATH"
export FLUTTER_ROOT="$SDK_DIR"
export CC=clang
export CXX=clang++
cd "$PROJECT_ROOT"
echo ""
echo "cs_monero Guix dev shell ready."
echo "  Flutter:    \$(flutter --version | head -1)"
echo "  clang:      \$(clang --version | head -1)"
echo "  cmake:      \$(cmake --version | head -1)"
echo ""
echo "Useful commands:"
echo "  melos bs                  # bootstrap melos packages"
echo "  melos build:linux         # build monero_c for linux"
echo "  melos copyLibs            # copy built libs to packages"
echo "  flutter build linux       # build example app (from example_app/)"
echo ""
INITEOF
)
