#!/bin/sh
# Digest to force a rebuild of the depends build image if
# any input change.

set -eu

cd "$(dirname "$0")/.."

inputs="tools/dart/env.dart
tools/dart/util.dart
tools/dart/bin/prepare_monero_c.dart
tools/dart/bin/sbs_cleanup.dart"

for f in $inputs patches/*.patch; do
  [ -r "$f" ] || { echo "error: builder_id input missing: $f" >&2; exit 1; }
done

{
  grep -vE '^[[:space:]]*(#|$)' builder/depends.Dockerfile
  sed '/^const kMoneroCHash = /d' $inputs patches/*.patch
} | sha256sum | cut -c1-12
