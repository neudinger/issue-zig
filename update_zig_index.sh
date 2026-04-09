#!/usr/bin/env bash
#
# Usage: ./update_zig_index.sh 0.16.0-dev.2722+f16eb18ce [0.16.0-dev.3132+fd2718f82 ...]
#
# Fetches tarball URLs, sizes, and SHA256 checksums from ziglang.org
# and writes zig_index.json with entries for the given versions.
# Then run: bazel clean --expunge && bazel build //:issue

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT="$SCRIPT_DIR/zig_index.json"

PLATFORMS=(
  x86_64-linux    tar.xz
  aarch64-linux   tar.xz
  x86_64-macos    tar.xz
  aarch64-macos   tar.xz
  x86_64-windows  zip
  aarch64-windows zip
)

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 VERSION [VERSION ...]"
  echo "Example: $0 0.16.0-dev.2722+f16eb18ce 0.16.0-dev.3132+fd2718f82"
  exit 1
fi

echo "{"
FIRST_VERSION=true

for VERSION in "$@"; do
  echo "Fetching metadata for $VERSION ..." >&2

  # Determine the index key: use "master" if it looks like a dev build
  if [[ "$VERSION" == *"dev"* ]]; then
    KEY="$VERSION"
  else
    KEY="$VERSION"
  fi

  if [[ "$FIRST_VERSION" == "true" ]]; then
    FIRST_VERSION=false
  else
    echo ","
  fi

  cat <<EOF
  "$KEY": {
    "version": "$VERSION",
EOF

  FIRST_PLATFORM=true
  i=0
  while [[ $i -lt ${#PLATFORMS[@]} ]]; do
    PLATFORM="${PLATFORMS[$i]}"
    EXT="${PLATFORMS[$((i+1))]}"
    i=$((i+2))

    URL="https://ziglang.org/builds/zig-${PLATFORM}-${VERSION}.${EXT}"

    # Check if the file exists
    HTTP_CODE=$(curl -sI -o /dev/null -w "%{http_code}" "$URL" 2>/dev/null || echo "000")
    if [[ "$HTTP_CODE" != "200" ]]; then
      echo "  SKIP $PLATFORM (HTTP $HTTP_CODE)" >&2
      continue
    fi

    echo "  Fetching $PLATFORM ..." >&2
    SIZE=$(curl -sI "$URL" | grep -i content-length | awk '{print $2}' | tr -d '\r')
    SHASUM=$(curl -sL "$URL" | sha256sum | awk '{print $1}')

    if [[ "$FIRST_PLATFORM" == "true" ]]; then
      FIRST_PLATFORM=false
    else
      echo ","
    fi

    cat <<EOF2
    "$PLATFORM": {
      "tarball": "$URL",
      "shasum": "$SHASUM",
      "size": "$SIZE"
    }
EOF2

  done

  echo ""
  echo "  }"

done

echo ""
echo "}"
