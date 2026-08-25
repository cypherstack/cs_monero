#!/bin/sh
# Tree hash of contrib/depends at the pinned monero_c commit: this is the part
# the pin the depends image depends on, so a bump that leaves it
# untouched keeps the image tag.

set -eu

cd "$(dirname "$0")/.."

repo=$(sed -n 's/.*kMoneroCRepo = "\([^"]*\)".*/\1/p' tools/dart/env.dart)
hash=$(sed -n 's/.*kMoneroCHash = "\([0-9a-f]*\)".*/\1/p' tools/dart/env.dart)

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM

# Fetch only the commit and its trees.
git init -q "$tmp"
git -C "$tmp" fetch -q --depth 1 --filter=blob:none "$repo" "$hash"
git -C "$tmp" rev-parse "$hash:contrib/depends" | cut -c1-12
