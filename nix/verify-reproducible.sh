#!/usr/bin/env bash
set -euo pipefail

flake_ref="${1:-.#cs-monero}"
nix build "$flake_ref" --no-link
first="$(nix path-info "$flake_ref")"
first_hash="$(sha256sum "$first/lib/libmonero_libwallet2_api_c.so" | cut -d' ' -f1)"
nix build "$flake_ref" --no-link --rebuild
second="$(nix path-info "$flake_ref")"
second_hash="$(sha256sum "$second/lib/libmonero_libwallet2_api_c.so" | cut -d' ' -f1)"
test "$first_hash" = "$second_hash"
printf '%s  libmonero_libwallet2_api_c.so\n' "$first_hash"
