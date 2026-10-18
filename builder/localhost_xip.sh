#!/bin/sh
# Serve a locally downloaded Xcode xip as a SIMPLYBS_MIRROR for apple builds.
# The xip must be fetched under your own Apple Developer account first.
# Works on linux (docker bridge) and macos (Docker Desktop style VM);
# HOST_IP and BIND_IP override the per-platform defaults.

set -eu

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: $0 <XcodeXIP_<version>_Universal.xip> [port]" >&2
  exit 2
fi

xip=$1
port=${2:-8321}

[ -r "$xip" ] || { echo "error: cannot read $xip" >&2; exit 1; }
case "$port" in
  ''|*[!0-9]*) echo "error: port must be a number: $port" >&2; exit 1 ;;
esac
{ [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; } \
  || { echo "error: port out of range: $port" >&2; exit 1; }
command -v python3 >/dev/null || { echo "error: python3 is required" >&2; exit 1; }

# realpath is missing on older macos
abspath() {
  if command -v realpath >/dev/null; then
    realpath "$1"
  else
    (cd "$(dirname "$1")" && printf '%s/%s\n' "$(pwd)" "$(basename "$1")")
  fi
}

# macos ships shasum, linux sha256sum
sha256() {
  if command -v sha256sum >/dev/null; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

xip_abs=$(abspath "$xip")

# Version from the file name, e.g. XcodeXIP_26.1_Universal.xip -> 26.1
version=$(basename "$xip" | sed -n 's/^XcodeXIP_\(.*\)_Universal\.xip$/\1/p')
[ -n "$version" ] || {
  echo "error: file name must match XcodeXIP_<version>_Universal.xip" >&2
  exit 1
}

# Refuse early when the local monero_c checkout pins another Xcode version;
# the build only ever requests the pinned path.
repo=$(cd "$(dirname "$0")/.." && pwd)
pin_json="$repo/build/monero_c/contrib/depends/simplybs/packages/native/apple-sdk.json"
pin_sha=
if [ -r "$pin_json" ]; then
  pin_version=$(sed -n 's/.*Developer_Tools\/Xcode_\([^/]*\)\/.*/\1/p' "$pin_json" | head -1)
  pin_sha=$(grep -o '"sha256": *"[0-9a-f]\{64\}"' "$pin_json" \
    | sed 's/.*\([0-9a-f]\{64\}\).*/\1/' | head -1)
  if [ -n "$pin_version" ] && [ "$pin_version" != "$version" ]; then
    echo "error: monero_c pins Xcode $pin_version, this file is $version" >&2
    exit 1
  fi
fi

# Containers reach the host per platform: on linux through the docker bridge,
# on macos through the VM's host.docker.internal name while the server binds
# loopback. url_host goes into SIMPLYBS_MIRROR, bind_ip is what python binds.
if [ "$(uname -s)" = "Darwin" ]; then
  url_host=${HOST_IP:-host.docker.internal}
  bind_ip=${BIND_IP:-127.0.0.1}
else
  url_host=${HOST_IP:-$(ip -4 -o addr show docker0 2>/dev/null \
    | awk '{sub(/\/.*/, "", $4); print $4; exit}')}
  [ -n "$url_host" ] || {
    echo "error: docker0 bridge not found;" \
      "set HOST_IP=<address reachable from build containers>" >&2
    exit 1
  }
  bind_ip=${BIND_IP:-$url_host}
fi

# Unguessable path prefix keeps the xip private on the docker network.
token=$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')
[ -n "$token" ] || { echo "error: token generation failed" >&2; exit 1; }

# The tree lives beside the xip so it can be hardlinked; a hardlink keeps
# serving even if the original is moved or deleted during the build.
root=$(mktemp -d "$(dirname "$xip_abs")/.host_xip.XXXXXX" 2>/dev/null) \
  || root=$(mktemp -d)

server_pid=
cleanup() {
  [ -n "$server_pid" ] && kill "$server_pid" 2>/dev/null || :
  rm -rf "$root"
}
trap cleanup EXIT
trap 'cleanup; trap - EXIT; exit 130' INT
trap 'cleanup; trap - EXIT; exit 143' TERM HUP

dir="$root/$token/download.developer.apple.com/Developer_Tools/Xcode_${version}"
mkdir -p "$dir"
file="$dir/XcodeXIP_${version}_Universal.xip"
ln "$xip_abs" "$file" 2>/dev/null || ln -s "$xip_abs" "$file"

url_path="$token/download.developer.apple.com/Developer_Tools/Xcode_${version}/XcodeXIP_${version}_Universal.xip"
url="http://$url_host:$port/$url_path"

probe() {
  python3 - "$1" 2>/dev/null <<'EOF'
import sys, urllib.request
urllib.request.urlopen(
    urllib.request.Request(sys.argv[1], method="HEAD"), timeout=1)
EOF
}

python3 -m http.server "$port" --bind "$bind_ip" --directory "$root" &
server_pid=$!

tries=0
until probe "http://$bind_ip:$port/$url_path"; do
  kill -0 "$server_pid" 2>/dev/null \
    || { server_pid=; echo "error: server failed to start" >&2; exit 1; }
  tries=$((tries + 1))
  [ "$tries" -lt 30 ] \
    || { echo "error: server does not answer on $bind_ip:$port" >&2; exit 1; }
  sleep 0.1
done

cat <<EOF
Serving on $bind_ip:$port (local and docker only, the LAN cannot connect).

Keep this running for the entire build: both docker stages fetch the xip.
From another terminal:

  export SIMPLYBS_MIRROR="http://$url_host:$port/$token/"
  PLATFORMS="macos ios" $repo/builder/release.sh

Reachability check from a container, if wanted:

  docker run --rm busybox wget -q -O /dev/null "$url"

Ctrl-C stops the server.
EOF

if [ -n "$pin_sha" ]; then
  echo "checking the file against the monero_c sha256 pin..."
  sha=$(sha256 "$file")
  if [ "$sha" != "$pin_sha" ]; then
    echo "error: sha256 mismatch, the build would reject this file:" >&2
    echo "  file $sha" >&2
    echo "  pin  $pin_sha" >&2
    exit 1
  fi
  echo "sha256 matches the pin."
else
  echo "note: sha256 not checked, no local monero_c checkout under build/."
fi

wait "$server_pid" && status=0 || status=$?
server_pid=
echo "server exited (status $status)" >&2
exit "$status"
