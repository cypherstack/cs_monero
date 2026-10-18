#!/bin/sh

set -eu

cd "$(dirname "$0")/.."
# Macos/Ios is not included by default since they need the Apple SDK to be given manually
PLATFORMS=${PLATFORMS:-"linux windows android"}
IMAGE=${IMAGE:-cs_monero-builder:local}
OUTDIR=${OUTDIR:-built_outputs}

if [ "${NO_CACHE:-}" = 1 ]; then
  no_cache=--no-cache
else
  no_cache=
fi

# Can build Apple platform only if a Apple SDK url is given
for platform in $PLATFORMS; do
  case "$platform" in
    macos|ios)
      if [ -z "${SIMPLYBS_MIRROR:-}" ]; then
        cat >&2 <<EOF
error: cannot build $platform: SIMPLYBS_MIRROR is not set.
    1. fetch XcodeXIP_<version>_Universal.xip under your own Apple Developer
       account
    2. host it so that
         <SIMPLYBS_MIRROR>download.developer.apple.com/Developer_Tools/Xcode_<version>/XcodeXIP_<version>_Universal.xip
       using auth or an unguessable path:
         (builder/localhost_xip.sh <path to xip> [port] does this locally and prints the export line)
    3. export SIMPLYBS_MIRROR=<base url, trailing slash required>

  The dependency image retains no SDK - the apple-sdk package and the source
  cache are dropped from it - so every apple build refetches the xip, and the
  mirror is required even with DEPENDS_IMAGE.
EOF
        exit 1
      fi
      ;;
  esac
done

if [ -z "${DEPENDS_TARGETS:-}" ]; then
  DEPENDS_TARGETS=
  for platform in $PLATFORMS; do
    case "$platform" in
      linux)   DEPENDS_TARGETS="$DEPENDS_TARGETS x86_64-linux-gnu" ;;
      windows) DEPENDS_TARGETS="$DEPENDS_TARGETS x86_64-w64-mingw32" ;;
      android) DEPENDS_TARGETS="$DEPENDS_TARGETS x86_64-linux-android armv7a-linux-androideabi aarch64-linux-android" ;;
      macos)   DEPENDS_TARGETS="$DEPENDS_TARGETS aarch64-apple-darwin" ;;
      ios)     DEPENDS_TARGETS="$DEPENDS_TARGETS aarch64-apple-ios" ;;
      *)
        echo "error: unknown platform '$platform'" >&2
        exit 1
        ;;
    esac
  done
  DEPENDS_TARGETS=${DEPENDS_TARGETS# }
fi

if [ -n "${DEPENDS_IMAGE:-}" ]; then
  docker image inspect "$DEPENDS_IMAGE" >/dev/null 2>&1 || docker pull "$DEPENDS_IMAGE"

  status=0
  builder/depends_usable.sh "$DEPENDS_IMAGE" $DEPENDS_TARGETS || status=$?
  if [ "$status" -eq 3 ]; then
    cat >&2 <<EOF
error: $DEPENDS_IMAGE does not contain every triple this build needs:
   $DEPENDS_TARGETS

  Unset DEPENDS_IMAGE to build a matching one.
EOF
    exit 1
  elif [ "$status" -ne 0 ]; then
    echo "error: could not inspect $DEPENDS_IMAGE (exit $status); see docker output above" >&2
    exit 1
  fi
else
  DEPENDS_IMAGE=cs_monero-depends:local

  set -- --file builder/depends.Dockerfile --tag "$DEPENDS_IMAGE"
  [ -n "$no_cache" ] && set -- "$@" "$no_cache"
  if [ -n "${DEPENDS_TARGETS:-}" ]; then
    set -- "$@" --build-arg "DEPENDS_TARGETS=$DEPENDS_TARGETS"
  fi
  if [ -n "${SIMPLYBS_MIRROR:-}" ]; then
    set -- "$@" --secret id=simplybs_mirror,env=SIMPLYBS_MIRROR
  fi

  echo "==> dependency tree (this is the slow one)"
  docker build "$@" .
fi

set -- \
  --file builder/libs.Dockerfile \
  --tag "$IMAGE" \
  --build-arg "DEPENDS_IMAGE=$DEPENDS_IMAGE" \
  --build-arg "PLATFORMS=$PLATFORMS"
[ -n "$no_cache" ] && set -- "$@" "$no_cache"
if [ -n "${SIMPLYBS_MIRROR:-}" ]; then
  set -- "$@" --secret id=simplybs_mirror,env=SIMPLYBS_MIRROR
fi

echo "==> libraries: $PLATFORMS"
docker build "$@" .

container=$(docker create "$IMAGE" /bin/true)
trap "docker rm -f '$container' >/dev/null 2>&1 || true" EXIT INT TERM

# Replaces each requested platform's output, leaving any other platform's alone.
for platform in $PLATFORMS; do
  rm -rf "${OUTDIR:?}/$platform"
  mkdir -p "$OUTDIR"
  docker cp "$container:/w/built_outputs/$platform" "$OUTDIR/$platform"
done

echo "==> $OUTDIR"
