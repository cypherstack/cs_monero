#!/bin/sh
# Exit 0 if the dependency image holds a completion stamp for every triple
# asked, 3 if any stamp is missing.

set -eu

if [ "$#" -lt 2 ]; then
  echo "usage: $0 <image> <triple>..." >&2
  exit 2
fi

image=$1
shift

docker run --rm "$image" sh -c '
      stamps=/w/build/monero_c/contrib/depends/simplybs/.buildlib/complete

      for triple in "$@"; do
        [ -e "$stamps/$triple" ] || exit 3
      done
    ' sh "$@"
